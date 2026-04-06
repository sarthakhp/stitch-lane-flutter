import 'dart:convert';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:toonx/toonx.dart' as toonx;
import '../../utils/app_logger.dart';
import 'ai_chat_history.dart';
import 'ai_chat_models.dart';
import 'ai_tool_service.dart';

/// Result of a single AI exchange (one user message → one final response).
class AiExecutorResult {
  final String rawResponse;
  final String responseText;
  final List<UiComponent> uiComponents;
  final List<ToolCallRecord> toolCalls;
  final AiTokenUsage usage;

  AiExecutorResult({
    required this.rawResponse,
    required this.responseText,
    required this.uiComponents,
    required this.toolCalls,
    required this.usage,
  });
}

/// Runs the model invoke → tool call → re-invoke loop with safety limits.
///
/// Inspired by LangChain's AgentExecutor, with:
/// - Max iterations guard
/// - Wall-clock time limit (Stopwatch)
/// - Per-invoke timeout
/// - Unknown tool recovery
/// - Structured JSON response parsing
class AiExecutor {
  static const _maxIterations = 5;
  static const _maxExecutionTime = Duration(seconds: 60);
  static const _perInvokeTimeout = Duration(seconds: 30);

  /// Execute a single exchange: send messages to the model, handle tool calls,
  /// and return the parsed response.
  static Future<AiExecutorResult> run(
    ChatGoogleGenerativeAI model,
    List<ChatMessage> history, {
    String? systemPrompt,
  }) async {
    final toolCallRecords = <ToolCallRecord>[];
    var totalUsage = AiTokenUsage.zero;
    final steps = <Map<String, dynamic>>[];
    final stopwatch = Stopwatch()..start();

    var result = await model.invoke(PromptValue.chat(history)).timeout(_perInvokeTimeout);
    var stepUsage = _usageFrom(result);
    totalUsage = totalUsage + stepUsage;
    var aiMessage = result.output;

    steps.add(_buildStepLog('initial', stepUsage, aiMessage));
    history.add(aiMessage);

    var iterations = 0;
    while (aiMessage.toolCalls.isNotEmpty && _shouldContinue(iterations, stopwatch.elapsed)) {
      iterations++;
      final toolCall = aiMessage.toolCalls.first;
      final toolResult = await _executeTool(toolCall, toolCallRecords);
      steps.last['tool_sql'] = toolCall.arguments['sql'];
      steps.last['tool_result'] = toolResult;

      history.add(ChatMessage.tool(toolCallId: toolCall.id, content: toolResult));

      // On last allowed iteration, invoke without tools to force a text response
      if (!_shouldContinue(iterations, stopwatch.elapsed)) {
        result = await model.invoke(
          PromptValue.chat(history),
          options: const ChatGoogleGenerativeAIOptions(tools: []),
        ).timeout(_perInvokeTimeout);
      } else {
        result = await model.invoke(PromptValue.chat(history)).timeout(_perInvokeTimeout);
      }
      stepUsage = _usageFrom(result);
      totalUsage = totalUsage + stepUsage;
      aiMessage = result.output;

      steps.add(_buildStepLog('after_tool', stepUsage, aiMessage));
      history.add(aiMessage);
    }

    clearThoughtSignatureCache();

    final stoppedEarly = aiMessage.toolCalls.isNotEmpty;
    final rawContent = aiMessage.content;

    final parsed = _parseStructuredResponse(rawContent);

    _logExchange(
      systemPrompt: systemPrompt,
      userMessage: history.whereType<HumanChatMessage>().last.contentAsString,
      rawResponse: rawContent,
      steps: steps,
      usage: totalUsage,
      uiComponents: parsed.uiComponents,
      stoppedEarly: stoppedEarly,
    );

    return AiExecutorResult(
      rawResponse: rawContent,
      responseText: parsed.text,
      uiComponents: parsed.uiComponents,
      toolCalls: toolCallRecords,
      usage: totalUsage,
    );
  }

  // --- Loop control ---

  static bool _shouldContinue(int iterations, Duration elapsed) {
    return iterations < _maxIterations && elapsed < _maxExecutionTime;
  }

  // --- Tool execution ---

  static Future<String> _executeTool(
    AIChatMessageToolCall toolCall,
    List<ToolCallRecord> records,
  ) async {
    if (toolCall.name == 'queryDatabase') {
      final toolResult = await AiToolService.queryDatabase(
        toolCall.arguments['sql'] as String,
      );
      final resultToon = toonx.encode(toolResult.toJson());
      records.add(ToolCallRecord(
        id: toolCall.id,
        name: toolCall.name,
        arguments: toolCall.arguments,
        response: resultToon,
      ));
      return resultToon;
    }

    // Unknown tool — recoverable message so the model can self-correct
    final observation = '${toolCall.name} is not a valid tool. '
        'Available tools: queryDatabase. Please try again.';
    records.add(ToolCallRecord(
      id: toolCall.id,
      name: toolCall.name,
      arguments: toolCall.arguments,
      response: observation,
    ));
    return observation;
  }

  // --- Response parsing ---

  static ({String text, List<UiComponent> uiComponents}) _parseStructuredResponse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final text = json['response_text'] as String? ?? raw;
      final components = (json['ui_components'] as List<dynamic>?)
              ?.map((e) => UiComponent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return (text: text, uiComponents: components);
    } catch (_) {
      return (text: raw, uiComponents: <UiComponent>[]);
    }
  }

  // --- Logging ---

  static AiTokenUsage _usageFrom(ChatResult result) => AiTokenUsage(
        promptTokens: result.usage.promptTokens ?? 0,
        responseTokens: result.usage.responseTokens ?? 0,
        totalTokens: result.usage.totalTokens ?? 0,
      );

  static Map<String, dynamic> _buildStepLog(String label, AiTokenUsage usage, AIChatMessage ai) {
    return {
      'step': label,
      'tokens': {'in': usage.promptTokens, 'out': usage.responseTokens},
      if (ai.toolCalls.isNotEmpty)
        'tool_call': ai.toolCalls.first.name
      else
        'response': ai.content,
    };
  }

  static void _logExchange({
    required String userMessage,
    required String? rawResponse,
    required List<Map<String, dynamic>> steps,
    required AiTokenUsage usage,
    String? systemPrompt,
    List<UiComponent>? uiComponents,
    String? error,
    bool stoppedEarly = false,
  }) {
    final logObj = {
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      'user': userMessage,
      'steps': steps,
      'raw_response': rawResponse,
      'ui_components': uiComponents?.map((c) => c.toJson()).toList(),
      'tokens': {
        'in': usage.promptTokens,
        'out': usage.responseTokens,
        'total': usage.totalTokens,
      },
      if (stoppedEarly) 'stopped_early': true,
      if (error != null) 'error': error,
    };
    final logStr = jsonEncode(logObj);
    const chunkSize = 800;
    for (var i = 0; i < logStr.length; i += chunkSize) {
      final end = (i + chunkSize < logStr.length) ? i + chunkSize : logStr.length;
      final prefix = i == 0 ? 'AI_EXCHANGE: ' : 'AI_EXCHANGE+: ';
      AppLogger.info('$prefix${logStr.substring(i, end)}');
    }
  }
}
