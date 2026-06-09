import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../domain/services/ai_action/ai_action_runner.dart';
import '../domain/services/ai_action/action_labels.dart';
import '../domain/services/ai_action/proposed_action.dart';
import '../domain/services/ai_gateway/pricing.dart';
import '../domain/services/recordings/recording_metadata.dart';
import '../domain/services/recordings/recording_store.dart';
import '../domain/services/ai_gateway/usage_event.dart';
import '../domain/services/ai_chat_models.dart';
import '../domain/services/ai_chat_service.dart';
import '../domain/services/tts_service.dart';
import '../domain/state/order_state.dart';
import '../domain/state/settings_state.dart';
import '../presentation/presentation.dart';
import 'widgets/ai/action/ai_proposed_action_card.dart';
import 'widgets/ai/ai_message_bubble.dart';
import 'widgets/ai/ai_typing_indicator.dart';
import 'widgets/ai/ai_welcome_view.dart';

class AiAssistantScreen extends StatefulWidget {
  /// When true the chat opens with the mic already listening. Used by the
  /// home-screen widget deep link.
  final bool autoStartVoice;

  /// Whether this tab is currently the visible one. When it goes false, an
  /// in-progress voice recording is paused (no background recording).
  final bool active;

  const AiAssistantScreen({
    super.key,
    this.autoStartVoice = false,
    this.active = true,
  });

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

  Future<void> _sendMessage(
    String text, {
    bool wasVoiceInput = false,
    String? audioWavPath,
  }) async {
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
          proposedActions: response.proposedActions,
        ));
        _isLoading = false;
      });
      await _chatService.saveChat();
      _scrollToBottom();

      // Best-effort: link the voice recording to what was asked and what the
      // AI proposed, so it surfaces in the Recordings debugger.
      if (wasVoiceInput && audioWavPath != null) {
        await RecordingStore.writeSidecar(
          audioWavPath,
          RecordingMetadata(
            source: RecordingSource.assistant,
            transcript: trimmed,
            actions: [
              if (response.text.trim().isNotEmpty)
                'Reply: ${response.text.trim()}',
              for (final a in response.proposedActions)
                'Proposed: ${ActionLabels.changeSummary(a)}'
                    '${_candidateNames(a).isEmpty ? '' : ' — ${_candidateNames(a)}'}',
            ],
          ),
        );
      }

      if (wasVoiceInput && response.text.isNotEmpty) {
        _ttsService.speak(response.text, speaker: settings.ttsSpeaker);
      }
    }
  }

  /// Distinct customer names across an action's candidates, for the recording
  /// sidecar's "what the AI did" line.
  String _candidateNames(ProposedAction action) =>
      action.candidates.map((c) => c.title).toSet().join(', ');

  Future<void> _confirmAction(
    int messageIndex,
    ProposedAction action,
    List<String> orderIds,
  ) async {
    // Read context-bound deps up front — the rest is async.
    final orderState = context.read<OrderState>();
    final orderRepo = context.read<OrderRepository>();
    final wasVoice = _messages[messageIndex].wasVoiceInput;
    final ttsSpeaker = context.read<SettingsState>().settings.ttsSpeaker;

    final result = await AiActionRunner.run(
      action,
      orderIds: orderIds,
      orderState: orderState,
      orderRepo: orderRepo,
    );
    final status = result.ok ? ActionStatus.done : ActionStatus.failed;

    _applyActionOutcome(messageIndex, action.id, status, result.message,
        executedOrderIds: result.executedOrderIds);
    await _chatService.updateActionOutcome(action.id, status,
        resultMessage: result.message,
        executedOrderIds: result.executedOrderIds);

    if (mounted && wasVoice && result.ok) {
      _ttsService.speak(result.message, speaker: ttsSpeaker);
    }
  }

  Future<void> _openOrder(String orderId) async {
    final orderRepo = context.read<OrderRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final order = await orderRepo.getOrderById(orderId);
    if (order == null || !mounted) return;
    final customer = await customerRepo.getCustomerById(order.customerId);
    if (customer == null || !mounted) return;
    Navigator.pushNamed(
      context,
      AppConstants.orderDetailRoute,
      arguments: {'order': order, 'customer': customer},
    );
  }

  void _cancelAction(int messageIndex, ProposedAction action) {
    _applyActionOutcome(messageIndex, action.id, ActionStatus.cancelled, null);
    _chatService.updateActionOutcome(action.id, ActionStatus.cancelled);
  }

  /// Replaces a single action on a message with its new status (immutable
  /// update) so the card re-renders.
  void _applyActionOutcome(
    int messageIndex,
    String actionId,
    ActionStatus status,
    String? message, {
    List<String> executedOrderIds = const [],
  }) {
    if (!mounted || messageIndex >= _messages.length) return;
    final message0 = _messages[messageIndex];
    final updatedActions = message0.proposedActions
        .map((a) => a.id == actionId
            ? a.copyWith(
                status: status,
                resultMessage: message,
                executedOrderIds: executedOrderIds,
              )
            : a)
        .toList();
    setState(() {
      _messages[messageIndex] =
          message0.copyWith(proposedActions: updatedActions);
    });
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
            active: widget.active,
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
        final message = _messages[index];
        final bubble = AiMessageBubble(message: message, ttsService: _ttsService);
        final Widget content = message.proposedActions.isEmpty
            ? bubble
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bubble,
                  for (final action in message.proposedActions)
                    AiProposedActionCard(
                      key: ValueKey(action.id),
                      action: action,
                      onConfirm: (a, orderIds) =>
                          _confirmAction(index, a, orderIds),
                      onCancel: (a) => _cancelAction(index, a),
                      onOpen: _openOrder,
                    ),
                ],
              );
        final isLastMessage = index == _messages.length - 1;
        if (!isLastMessage) return content;
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
          child: content,
        );
      },
    );
  }

  Widget _buildTokenUsage(BuildContext context) {
    final usage = _chatService.sessionUsage;
    if (usage.totalTokens == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Price against the actually-selected chat model (rates live in [Pricing]),
    // so the estimate stays correct when the model is changed in settings.
    final model = context.read<SettingsState>().settings.aiChatModel;
    final usd = Pricing.estimate(
      provider: UsageProvider.gemini,
      model: model,
      kind: UsageKind.chat,
      inputTokens: usage.promptTokens,
      outputTokens: usage.responseTokens,
    );
    final costInr = usd == null ? null : Pricing.toInr(usd);
    final costLabel = costInr == null
        ? '${usage.totalTokens} tokens'
        : '~\u20B9${costInr.toStringAsFixed(3)}';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Token Usage'),
            content: Text(
              'Model: $model\n'
              'Input tokens: ${usage.promptTokens}\n'
              'Output tokens: ${usage.responseTokens}\n'
              'Total tokens: ${usage.totalTokens}\n'
              '${costInr == null ? 'Estimated cost: rate unavailable for this model' : 'Estimated cost: ~\u20B9${costInr.toStringAsFixed(3)}'}',
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
              costLabel,
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
