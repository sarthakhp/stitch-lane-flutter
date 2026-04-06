import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import '../../utils/app_logger.dart';
import 'ai_chat_config.dart';
import 'ai_chat_history.dart';
import 'ai_chat_models.dart';
import 'ai_executor.dart';

class AiChatService {
  ChatGoogleGenerativeAI? _model;
  List<ChatExchange> _exchanges = [];
  AiTokenUsage _sessionUsage = AiTokenUsage.zero;

  AiTokenUsage get sessionUsage => _sessionUsage;

  void _ensureModel() {
    if (_model != null) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception('GEMINI_API_KEY not found in .env file.');
    }

    _model = ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: const ChatGoogleGenerativeAIOptions(
        model: aiModelName,
        tools: aiTools,
        responseMimeType: 'application/json',
        responseSchema: aiResponseSchema,
      ),
    );
  }

  Future<List<AiChatMessage>> loadChat() async {
    _ensureModel();
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

  Future<AiChatResponse> sendMessage(String userMessage) async {
    _ensureModel();

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
      final result = await AiExecutor.run(_model!, history, systemPrompt: systemPrompt);

      _exchanges.add(ChatExchange(
        userText: userMessage,
        assistantText: result.responseText,
        toolCalls: result.toolCalls,
        uiComponents: result.uiComponents,
      ));
      _sessionUsage = _sessionUsage + result.usage;

      return AiChatResponse(
        text: result.responseText,
        usage: result.usage,
        uiComponents: result.uiComponents,
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

  void dispose() {
    _exchanges.clear();
    _model = null;
  }
}
