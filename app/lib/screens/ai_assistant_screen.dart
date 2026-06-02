import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/services/ai_chat_models.dart';
import '../domain/services/ai_chat_service.dart';
import '../domain/services/tts_service.dart';
import '../domain/state/settings_state.dart';
import '../presentation/presentation.dart';
import 'widgets/ai/ai_message_bubble.dart';
import 'widgets/ai/ai_typing_indicator.dart';
import 'widgets/ai/ai_welcome_view.dart';

class AiAssistantScreen extends StatefulWidget {
  /// When true the chat opens with the mic already listening. Used by the
  /// home-screen widget deep link.
  final bool autoStartVoice;

  const AiAssistantScreen({super.key, this.autoStartVoice = false});

  @override
  State<AiAssistantScreen> createState() => AiAssistantScreenState();
}

class AiAssistantScreenState extends State<AiAssistantScreen> {
  final _chatService = AiChatService();
  final _ttsService = TtsService();
  final _messages = <AiChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isInitializing = true;

  // Bumping this re-creates the input area in voice mode — lets the shell
  // (re)start the mic on demand, e.g. when opened from the home-screen widget,
  // even though this screen lives on as a persistent tab.
  int _voiceKick = 0;

  /// Open the mic now. Called by the shell when the AI tab is opened with a
  /// voice request (home-screen widget "Chat").
  void startVoiceInput() {
    if (!mounted) return;
    setState(() => _voiceKick++);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedChat();
  }

  Future<void> _loadSavedChat() async {
    final modelName = context.read<SettingsState>().settings.aiChatModel;
    final saved = await _chatService.loadChat(modelName: modelName);
    if (mounted) {
      setState(() {
        _messages.addAll(saved);
        _isInitializing = false;
      });
      if (_messages.isNotEmpty) _scrollToBottom(jump: true);
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    _chatService.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {bool wasVoiceInput = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    if (_ttsService.isActive) _ttsService.stop();

    _inputController.clear();
    setState(() {
      _messages.add(AiChatMessage(text: trimmed, isUser: true, wasVoiceInput: wasVoiceInput));
      _isLoading = true;
    });
    _scrollToBottom();

    final settings = context.read<SettingsState>().settings;
    final response = await _chatService.sendMessage(
      trimmed,
      customerRepo: context.read<CustomerRepository>(),
      orderRepo: context.read<OrderRepository>(),
      modelName: settings.aiChatModel,
    );

    if (mounted) {
      setState(() {
        _messages.add(AiChatMessage(
          text: response.text,
          isUser: false,
          wasVoiceInput: wasVoiceInput,
          uiComponents: response.uiComponents,
        ));
        _isLoading = false;
      });
      await _chatService.saveChat();
      _scrollToBottom();

      if (wasVoiceInput && response.text.isNotEmpty) {
        _ttsService.speak(response.text, speaker: settings.ttsSpeaker);
      }
    }
  }

  Future<void> _startNewChat() async {
    await _ttsService.stop();
    await _chatService.clearChat();
    if (mounted) {
      setState(() {
        _messages.clear();
      });
    }
  }

  

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        // Second pass after cards finish loading
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Stitch Genie'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _isLoading ? null : _startNewChat,
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New Chat',
            ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? AiWelcomeView(onSuggestionTap: _sendMessage)
                : _buildMessageList(context),
          ),
          _buildTokenUsage(context),
          AiInputArea(
            key: ValueKey('ai_input_$_voiceKick'),
            controller: _inputController,
            isLoading: _isLoading,
            onSend: _sendMessage,
            autoStartVoice: widget.autoStartVoice || _voiceKick > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final totalItems = _messages.length + (_isLoading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const AiTypingIndicator();
        }
        final bubble = AiMessageBubble(message: _messages[index], ttsService: _ttsService);
        final isLastMessage = index == _messages.length - 1;
        if (!isLastMessage) return bubble;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: bubble,
        );
      },
    );
  }

  Widget _buildTokenUsage(BuildContext context) {
    final usage = _chatService.sessionUsage;
    if (usage.totalTokens == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const inputRatePerToken = 0.25 / 1000000 * 93;
    const outputRatePerToken = 1.50 / 1000000 * 93;
    final costInr = (usage.promptTokens * inputRatePerToken) +
        (usage.responseTokens * outputRatePerToken);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Token Usage'),
            content: Text(
              'Input tokens: ${usage.promptTokens}\n'
              'Output tokens: ${usage.responseTokens}\n'
              'Total tokens: ${usage.totalTokens}\n'
              'Estimated cost: ~\u20B9${costInr.toStringAsFixed(3)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppConfig.spacing4),
            Text(
              '~\u20B9${costInr.toStringAsFixed(3)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
