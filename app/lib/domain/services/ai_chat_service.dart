import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:toonx/toonx.dart' as toonx;
import '../../utils/app_logger.dart';
import 'ai_chat_config.dart';
import 'ai_chat_history.dart';
import 'ai_chat_models.dart';
import 'ai_tool_service.dart';

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
              AiChatMessage(text: e.assistantText, isUser: false),
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

    final history = AiChatHistory.buildLangchainHistory(buildAiSystemPrompt(), _exchanges);
    history.add(ChatMessage.humanText(userMessage));

    final toolCallRecords = <ToolCallRecord>[];
    var exchangeUsage = AiTokenUsage.zero;
    int invokeCount = 0;
    final log = StringBuffer();

    _logHistory(log, history);

    try {
      var result = await _model!.invoke(PromptValue.chat(history));
      var stepUsage = _usageFrom(result);
      exchangeUsage = exchangeUsage + stepUsage;
      invokeCount++;
      var aiMessage = result.output;

      _logInvoke(log, invokeCount, 'initial', stepUsage, aiMessage);
      history.add(aiMessage);

      while (aiMessage.toolCalls.isNotEmpty) {
        final toolCall = aiMessage.toolCalls.first;
        final resultJson = await _executeTool(toolCall, toolCallRecords, log);

        history.add(ChatMessage.tool(toolCallId: toolCall.id, content: resultJson));

        result = await _model!.invoke(PromptValue.chat(history));
        stepUsage = _usageFrom(result);
        exchangeUsage = exchangeUsage + stepUsage;
        invokeCount++;
        aiMessage = result.output;

        _logInvoke(log, invokeCount, 'after tool', stepUsage, aiMessage, historyLength: history.length);
        history.add(aiMessage);
      }

      final responseText = aiMessage.content;

      _logSummary(log, userMessage, responseText, toolCallRecords.length, invokeCount, exchangeUsage);
      AppLogger.info('AI Exchange:\n$log');

      _exchanges.add(ChatExchange(
        userText: userMessage,
        assistantText: responseText,
        toolCalls: toolCallRecords,
      ));
      _sessionUsage = _sessionUsage + exchangeUsage;

      return AiChatResponse(text: responseText, usage: exchangeUsage);
    } catch (e) {
      AppLogger.error('AI chat error', e);
      AppLogger.info('AI Exchange (failed):\n$log');
      return AiChatResponse(text: 'Something went wrong. Please try again.', usage: exchangeUsage);
    }
  }

  Future<String> _executeTool(
    AIChatMessageToolCall toolCall,
    List<ToolCallRecord> records,
    StringBuffer log,
  ) async {
    if (toolCall.name == 'queryDatabase') {
      final sql = toolCall.arguments['sql'] as String;
      log.writeln('  tool sql: $sql');

      final toolResult = await AiToolService.queryDatabase(sql);
      final resultToon = toonx.encode(toolResult.toJson());

      if (toolResult.success) {
        log.writeln('  tool result: ${toolResult.totalRows} rows\n  $resultToon');
      } else {
        log.writeln('  tool result ERROR: ${toolResult.error}');
      }

      records.add(ToolCallRecord(
        id: toolCall.id,
        name: toolCall.name,
        arguments: toolCall.arguments,
        response: resultToon,
      ));
      return resultToon;
    }

    final errorJson = jsonEncode({'error': 'Unknown tool: ${toolCall.name}'});
    records.add(ToolCallRecord(
      id: toolCall.id,
      name: toolCall.name,
      arguments: toolCall.arguments,
      response: errorJson,
    ));
    return errorJson;
  }

  // --- Logging helpers ---

  AiTokenUsage _usageFrom(ChatResult result) => AiTokenUsage(
        promptTokens: result.usage.promptTokens ?? 0,
        responseTokens: result.usage.responseTokens ?? 0,
        totalTokens: result.usage.totalTokens ?? 0,
      );

  void _logHistory(StringBuffer log, List<ChatMessage> history) {
    log.writeln('--- history sent (${history.length} messages) ---');
    for (final msg in history) {
      switch (msg) {
        case SystemChatMessage():
          log.writeln('  [system] ${msg.content.length} chars');
        case HumanChatMessage():
          log.writeln('  [user] ${msg.contentAsString.length} chars');
        case AIChatMessage():
          if (msg.toolCalls.isNotEmpty) {
            log.writeln('  [ai-tool-call] ${msg.toolCalls.map((t) => t.name).join(", ")}');
          } else {
            log.writeln('  [ai] ${msg.content.length} chars');
          }
        case ToolChatMessage():
          log.writeln('  [tool-response] ${msg.content.length} chars');
        default:
          log.writeln('  [${msg.runtimeType}] ${msg.contentAsString.length} chars');
      }
    }
  }

  void _logInvoke(StringBuffer log, int count, String label, AiTokenUsage usage, AIChatMessage ai, {int? historyLength}) {
    log.writeln('--- invoke #$count ($label) ---');
    log.writeln('  tokens — in: ${usage.promptTokens}, out: ${usage.responseTokens}, total: ${usage.totalTokens}');
    if (historyLength != null) log.writeln('  history messages sent: $historyLength');
    if (ai.toolCalls.isNotEmpty) {
      log.writeln('  model requested tool call: ${ai.toolCalls.first.name}');
    } else {
      log.writeln('  model responded with text (${ai.content.length} chars)');
    }
  }

  void _logSummary(StringBuffer log, String user, String response, int toolCalls, int invokes, AiTokenUsage usage) {
    log.writeln('--- exchange summary ---');
    log.writeln('  user: $user');
    log.writeln('  response: ${response.length} chars');
    log.writeln('  tool calls: $toolCalls');
    log.writeln('  invoke count: $invokes');
    log.writeln('  total tokens — in: ${usage.promptTokens}, out: ${usage.responseTokens}, total: ${usage.totalTokens}');
  }

  void dispose() {
    _exchanges.clear();
    _model = null;
  }
}
