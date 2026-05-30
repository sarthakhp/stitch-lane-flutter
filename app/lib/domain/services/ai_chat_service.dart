import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
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

      _exchanges.add(ChatExchange(
        userText: userMessage,
        assistantText: result.responseText,
        toolCalls: result.toolCalls,
        uiComponents: enriched,
      ));
      _sessionUsage = _sessionUsage + result.usage;

      return AiChatResponse(
        text: result.responseText,
        usage: result.usage,
        uiComponents: enriched,
      );
    } catch (e) {
      AppLogger.error('AI chat error', e);
      clearThoughtSignatureCache();
      return AiChatResponse(
        text: 'Something went wrong. Please try again.',
        usage: AiTokenUsage.zero,
      );
    }
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
          final dueDateStr = '${order.dueDate.day}/${order.dueDate.month}/${order.dueDate.year}';

          final details = <String>[];
          if (order.title != null && order.title!.trim().isNotEmpty) details.add(order.title!);
          details.add(order.value == null ? 'Price not set' : '₹${order.value}');
          details.add('Due $dueDateStr');

          enriched.add(UiComponent(
            type: c.type, id: c.id,
            title: customer?.name ?? 'Order',
            details: details,
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

  void dispose() {
    _exchanges.clear();
    _model = null;
  }
}
