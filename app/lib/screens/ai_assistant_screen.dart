import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/gemini_prompts.dart';
import '../domain/services/ai_chat_models.dart';
import '../domain/services/ai_chat_service.dart';
import '../domain/state/settings_state.dart';
import '../domain/services/audio_recording_service.dart';
import '../domain/services/transcription_service.dart';
import '../presentation/presentation.dart';
import '../presentation/widgets/recording_dialog.dart';
import '../presentation/widgets/transcription_error_dialog.dart';
import 'widgets/ai/ai_input_bar.dart';
import 'widgets/ai/ai_message_bubble.dart';
import 'widgets/ai/ai_typing_indicator.dart';
import 'widgets/ai/ai_welcome_view.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _chatService = AiChatService();
  final _messages = <AiChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isInitializing = true;

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
    _chatService.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add(AiChatMessage(text: trimmed, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _chatService.sendMessage(
      trimmed,
      customerRepo: context.read<CustomerRepository>(),
      orderRepo: context.read<OrderRepository>(),
      modelName: context.read<SettingsState>().settings.aiChatModel,
    );

    if (mounted) {
      setState(() {
        _messages.add(AiChatMessage(
          text: response.text,
          isUser: false,
          uiComponents: response.uiComponents,
        ));
        _isLoading = false;
      });
      await _chatService.saveChat();
      _scrollToBottom();
    }
  }

  Future<void> _startNewChat() async {
    await _chatService.clearChat();
    if (mounted) {
      setState(() {
        _messages.clear();
      });
    }
  }

  Future<void> _handleVoiceInput() async {
    final audioPath = await RecordingDialog.show(context);
    if (audioPath == null || !mounted) return;

    var shouldRetry = true;
    while (shouldRetry && mounted) {
      shouldRetry = false;

      final result = await TranscriptionService.transcribe(
        // ignore: use_build_context_synchronously
        context: context,
        audioFilePath: audioPath,
        systemInstruction: GeminiPrompts.chatSystemInstruction,
        transcriptionPrompt: GeminiPrompts.chatTranscriptionPrompt,
        // ignore: use_build_context_synchronously
        modelName: context.read<SettingsState>().settings.aiVoiceModel,
      );

      if (result.type == TranscriptionResultType.success && result.text != null) {
        final existing = _inputController.text.trim();
        _inputController.text = existing.isEmpty ? result.text! : '$existing ${result.text!}';
        _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
        break;
      }

      if (result.type == TranscriptionResultType.cancelled || !mounted) break;

      final action = await TranscriptionErrorDialog.show(
        // ignore: use_build_context_synchronously
        context,
        errorMessage: result.errorMessage ?? 'Transcription failed',
        audioFilePath: audioPath,
      );

      shouldRetry = action == TranscriptionErrorAction.retry;
    }

    await AudioRecordingService.deleteTemporaryAudio();
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
          AiInputBar(
            controller: _inputController,
            isLoading: _isLoading,
            onSend: _sendMessage,
            onMicTap: _handleVoiceInput,
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
        final bubble = AiMessageBubble(message: _messages[index]);
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
