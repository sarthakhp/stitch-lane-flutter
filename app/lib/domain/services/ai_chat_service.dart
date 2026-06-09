import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import 'ai_action/proposed_action.dart';
import 'ai_gateway/ai_error.dart';
import 'ai_chat_config.dart';
import 'ai_chat_history.dart';
import 'ai_chat_models.dart';
import 'ai_executor.dart';

class AiChatService {
  ChatGoogleGenerativeAI? _model;
  String? _currentModelName;
  List<ChatExchange> _exchanges = [];
  AiTokenUsage _sessionUsage = AiTokenUsage.zero;

  AiTokenUsage get sessionUsage => _sessionUsage;

  void _ensureModel(String modelName) {
    if (_model != null && _currentModelName == modelName) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception('GEMINI_API_KEY not found in .env file.');
    }

    _model = ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: ChatGoogleGenerativeAIOptions(
        model: modelName,
        tools: aiTools,
        responseMimeType: 'application/json',
        responseSchema: aiResponseSchema,
      ),
    );
    _currentModelName = modelName;
  }

  Future<List<AiChatMessage>> loadChat({String modelName = defaultAiChatModel}) async {
    _ensureModel(modelName);
    _exchanges = await AiChatHistory.load();

    final savedUsage = await AiChatHistory.loadUsage();
    if (savedUsage != null) {
      _sessionUsage = AiTokenUsage(
        promptTokens: savedUsage['promptTokens'] ?? 0,
        responseTokens: savedUsage['responseTokens'] ?? 0,
        totalTokens: savedUsage['totalTokens'] ?? 0,
      );
    }

    return _exchanges
        .expand((e) => [
              AiChatMessage(text: e.userText, isUser: true),
              AiChatMessage(
                text: e.assistantText,
                isUser: false,
                uiComponents: e.uiComponents,
                proposedActions: e.proposedActions,
              ),
            ])
        .toList();
  }

  Future<void> saveChat() async {
    await AiChatHistory.save(_exchanges);
    await AiChatHistory.saveUsage({
      'promptTokens': _sessionUsage.promptTokens,
      'responseTokens': _sessionUsage.responseTokens,
      'totalTokens': _sessionUsage.totalTokens,
    });
  }

  Future<void> clearChat() async {
    _exchanges.clear();
    _sessionUsage = AiTokenUsage.zero;
    await AiChatHistory.clear();
  }

  Future<AiChatResponse> sendMessage(
    String userMessage, {
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    String modelName = defaultAiChatModel,
  }) async {
    _ensureModel(modelName);

    var systemPrompt = buildAiSystemPrompt();
    final historyText = AiChatHistory.buildHistoryText(_exchanges);
    if (historyText != null) {
      systemPrompt += '\n\nConversation history:\n$historyText';
    }
    final history = <ChatMessage>[
      ChatMessage.system(systemPrompt),
      ChatMessage.humanText(userMessage),
    ];

    try {
      final result = await AiExecutor.run(
        _model!,
        history,
        modelName: modelName,
        systemPrompt: systemPrompt,
      );

      final enriched = await _enrichComponents(
        result.uiComponents,
        customerRepo,
        orderRepo,
      );
      final enrichedActions = await _enrichActions(
        result.proposedActions,
        customerRepo,
        orderRepo,
      );

      // Drop navigation cards for orders that are already action candidates, so
      // a proposed change never shows a duplicate (action card + nav card).
      final actionOrderIds =
          enrichedActions.expand((a) => a.candidateOrderIds).toSet();
      final components = enriched
          .where((c) => !(c.type == 'order' && actionOrderIds.contains(c.id)))
          .toList();

      _exchanges.add(ChatExchange(
        userText: userMessage,
        assistantText: result.responseText,
        toolCalls: result.toolCalls,
        uiComponents: components,
        proposedActions: enrichedActions,
      ));
      _sessionUsage = _sessionUsage + result.usage;

      return AiChatResponse(
        text: result.responseText,
        usage: result.usage,
        uiComponents: components,
        proposedActions: enrichedActions,
      );
    } catch (e) {
      AppLogger.error('AI chat error', e);
      clearThoughtSignatureCache();
      // Surface the real reason (out of credits, rate-limited, offline, …)
      // instead of a generic message, so the tailor knows what to do.
      return AiChatResponse(
        text: describeAiError(e),
        usage: AiTokenUsage.zero,
      );
    }
  }

  /// Display lines shared by order nav cards and action candidates:
  /// [optional phone], [optional title], price, due date.
  List<String> _orderSummaryLines(Order order, {String? phone}) {
    final lines = <String>[];
    if (phone != null && phone.trim().isNotEmpty) lines.add(phone);
    if (order.title != null && order.title!.trim().isNotEmpty) {
      lines.add(order.title!);
    }
    lines.add(order.value == null ? 'Price not set' : '₹${order.value}');
    final d = order.dueDate;
    lines.add('Due ${d.day}/${d.month}/${d.year}');
    return lines;
  }

  Future<List<UiComponent>> _enrichComponents(
    List<UiComponent> components,
    CustomerRepository customerRepo,
    OrderRepository orderRepo,
  ) async {
    final enriched = <UiComponent>[];
    for (final c in components) {
      try {
        if (c.type == 'customer') {
          final customer = await customerRepo.getCustomerById(c.id);
          if (customer == null) { enriched.add(c); continue; }

          final orders = await orderRepo.getOrdersByCustomerId(customer.id);
          final pending = orders.where((o) => o.status == OrderStatus.pending).length;
          final ready = orders.where((o) => o.status == OrderStatus.ready).length;
          final unpaid = orders
              .where((o) => !o.isPaid)
              .fold<int>(0, (sum, o) => sum + o.outstanding);

          final details = <String>[];
          if (pending > 0) details.add('$pending pending');
          if (ready > 0) details.add('$ready ready');
          if (unpaid > 0) details.add('₹$unpaid unpaid');

          enriched.add(UiComponent(
            type: c.type, id: c.id,
            title: customer.name,
            details: details,
          ));
        } else if (c.type == 'order') {
          final order = await orderRepo.getOrderById(c.id);
          if (order == null) { enriched.add(c); continue; }

          final customer = await customerRepo.getCustomerById(order.customerId);

          enriched.add(UiComponent(
            type: c.type, id: c.id,
            title: customer?.name ?? 'Order',
            details: _orderSummaryLines(order),
            imagePaths: order.imagePaths,
          ));
        } else {
          enriched.add(c);
        }
      } catch (_) {
        enriched.add(c);
      }
    }
    return enriched;
  }

  /// Fills each proposed action's candidate order ids with display info
  /// (customer name, phone, order title, price, due date) so the confirm card
  /// can tell same-name customers apart. Drops ids that no longer exist.
  Future<List<ProposedAction>> _enrichActions(
    List<ProposedAction> actions,
    CustomerRepository customerRepo,
    OrderRepository orderRepo,
  ) async {
    final enriched = <ProposedAction>[];
    for (final action in actions) {
      final candidates = <ActionCandidate>[];
      for (final orderId in action.candidateOrderIds) {
        try {
          final order = await orderRepo.getOrderById(orderId);
          if (order == null) continue;
          final customer = await customerRepo.getCustomerById(order.customerId);

          candidates.add(ActionCandidate(
            orderId: orderId,
            title: customer?.name ?? 'Order',
            lines: _orderSummaryLines(order, phone: customer?.phoneNumber),
            imagePaths: order.imagePaths,
          ));
        } catch (_) {
          // Skip unreadable candidates rather than failing the whole turn.
        }
      }
      // Drop a proposal whose orders can't be resolved — no empty cards.
      if (candidates.isEmpty) continue;
      enriched.add(action.copyWith(candidates: candidates));
    }
    return enriched;
  }

  /// Records the outcome of a confirmed/cancelled action in the stored history
  /// (so a reloaded chat shows ✓ and follow-up turns know it happened) and
  /// persists. No-op if the action id isn't found.
  Future<void> updateActionOutcome(
    String actionId,
    ActionStatus status, {
    String? resultMessage,
    List<String> executedOrderIds = const [],
  }) async {
    for (var i = 0; i < _exchanges.length; i++) {
      final exchange = _exchanges[i];
      final idx =
          exchange.proposedActions.indexWhere((a) => a.id == actionId);
      if (idx < 0) continue;

      final updated = [...exchange.proposedActions];
      updated[idx] = updated[idx].copyWith(
        status: status,
        resultMessage: resultMessage,
        executedOrderIds: executedOrderIds,
      );
      _exchanges[i] = exchange.copyWith(proposedActions: updated);
      await saveChat();
      return;
    }
  }

  void dispose() {
    _exchanges.clear();
    _model = null;
  }
}
