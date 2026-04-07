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
import 'widgets/ai/ai_message_bubble.dart';
import 'widgets/ai/ai_typing_indicator.dart';

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
      if (_messages.isNotEmpty) _scrollToBottom();
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

    // Transcribe loop with retry support
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
        _inputController.text = result.text!;
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
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
        title: const Text('AI Assistant'),
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
                ? _buildWelcomeView(context)
                : _buildMessageList(context),
          ),
          _buildTokenUsage(context),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final suggestions = [
      'How many pending orders do I have?',
      'How much did I earn this month?',
      'Which customer has the most orders?',
      'Show orders due this week',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppConfig.spacing16),
            Text(
              'Ask me anything about your business',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConfig.spacing24),
            Wrap(
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing8,
              alignment: WrapAlignment.center,
              children: suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _sendMessage(suggestion),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const AiTypingIndicator();
        }
        return AiMessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildTokenUsage(BuildContext context) {
    final usage = _chatService.sessionUsage;
    if (usage.totalTokens == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Pricing: $0.25/M input, $1.50/M output → ₹ at 93/USD
    const inputRatePerToken = 0.25 / 1000000 * 93;
    const outputRatePerToken = 1.50 / 1000000 * 93;
    final costInr = (usage.promptTokens * inputRatePerToken) +
        (usage.responseTokens * outputRatePerToken);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing4,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Text(
        'Tokens — in: ${usage.promptTokens}  |  out: ${usage.responseTokens}  |  ~₹${costInr.toStringAsFixed(3)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: AppConfig.spacing12,
        right: AppConfig.spacing4,
        top: AppConfig.spacing8,
        bottom: MediaQuery.of(context).padding.bottom + AppConfig.spacing8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacing16,
                  vertical: AppConfig.spacing12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
              maxLines: null,
            ),
          ),
          const SizedBox(width: AppConfig.spacing4),
          IconButton(
            onPressed: _isLoading ? null : _handleVoiceInput,
            icon: const Icon(Icons.mic),
          ),
          IconButton.filled(
            onPressed: _isLoading ? null : () => _sendMessage(_inputController.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
