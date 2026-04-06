import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../config/app_config.dart';
import '../domain/services/ai_chat_models.dart';
import '../domain/services/ai_chat_service.dart';
import '../presentation/presentation.dart';

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
    final saved = await _chatService.loadChat();
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

    final response = await _chatService.sendMessage(trimmed);

    if (mounted) {
      setState(() {
        _messages.add(AiChatMessage(text: response.text, isUser: false));
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
          return _buildTypingIndicator(context);
        }
        return _buildMessageBubble(context, _messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, AiChatMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing12,
          vertical: AppConfig.spacing8,
        ),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  strong: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  tableHead: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  tableBody: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  tableBorder: TableBorder.all(
                    color: colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                  tableCellsPadding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.spacing8,
                    vertical: AppConfig.spacing4,
                  ),
                  listBullet: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  code: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                selectable: true,
              ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              return _TypingDot(delay: i * 200);
            }),
          ),
        ),
      ),
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
          IconButton.filled(
            onPressed: _isLoading ? null : () => _sendMessage(_inputController.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
