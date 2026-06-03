import 'dart:async';
import 'dart:convert';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:toonx/toonx.dart' as toonx;
import 'package:uuid/uuid.dart';
import '../../utils/app_logger.dart';
import 'ai_action/proposed_action.dart';
import 'ai_action/proposed_action_factory.dart';
import 'ai_chat_history.dart';
import 'ai_chat_models.dart';
import 'ai_gateway/ai_gateway.dart';
import 'ai_gateway/usage_event.dart';
import 'ai_query/ai_query_dispatcher.dart';

/// Result of a single AI exchange (one user message → one final response).
class AiExecutorResult {
  final String rawResponse;
  final String responseText;
  final List<UiComponent> uiComponents;
  final List<ProposedAction> proposedActions;
  final List<ToolCallRecord> toolCalls;
  final AiTokenUsage usage;

  AiExecutorResult({
    required this.rawResponse,
    required this.responseText,
    required this.uiComponents,
    required this.proposedActions,
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
  static const _maxIterations = 6;
  static const _maxExecutionTime = Duration(seconds: 60);
  static const _perInvokeTimeout = Duration(seconds: 30);

  /// Execute a single exchange: send messages to the model, handle tool calls,
  /// and return the parsed response.
  static Future<AiExecutorResult> run(
    ChatGoogleGenerativeAI model,
    List<ChatMessage> history, {
    required String modelName,
    String? systemPrompt,
  }) async {
    // One runId for this whole exchange. Each model.invoke() emits its own
    // UsageEvent row that carries this runId, so the dashboard can roll up
    // "what did one chat turn cost" without storing pre-aggregated data.
    final runId = const Uuid().v4();

    final toolCallRecords = <ToolCallRecord>[];
    final proposedActions = <ProposedAction>[];
    var totalUsage = AiTokenUsage.zero;
    final steps = <Map<String, dynamic>>[];
    final stopwatch = Stopwatch()..start();

    var result = await _invokeWithRecording(
      model,
      prompt: PromptValue.chat(history),
      modelName: modelName,
      runId: runId,
    );
    var stepUsage = _usageFrom(result);
    totalUsage = totalUsage + stepUsage;
    var aiMessage = result.output;

    steps.add(_buildStepLog('initial', stepUsage, aiMessage));
    history.add(aiMessage);

    var iterations = 0;
    while (aiMessage.toolCalls.isNotEmpty && _shouldContinue(iterations, stopwatch.elapsed)) {
      iterations++;
      final toolCall = aiMessage.toolCalls.first;
      // Write tools (propose_*) only stage a change — they never hit the
      // read-only dispatcher. Everything else routes to the query handlers.
      final String toolResult;
      if (ProposedActionFactory.isActionTool(toolCall.name)) {
        // A chatty model may split one change across several propose calls
        // (e.g. "mark all done"). Merge same-change proposals into one card by
        // unioning their order ids, so the user sees a single multi-select.
        final action =
            ProposedActionFactory.build(toolCall.name, toolCall.arguments);
        final existing = proposedActions.indexWhere((a) => a.sameChange(action));
        if (existing >= 0) {
          final union = <String>{
            ...proposedActions[existing].candidateOrderIds,
            ...action.candidateOrderIds,
          }.toList();
          proposedActions[existing] =
              proposedActions[existing].copyWith(candidateOrderIds: union);
        } else {
          proposedActions.add(action);
        }
        toolResult = ProposedActionFactory.stagedToolResult;
      } else {
        toolResult = await _executeTool(toolCall, toolCallRecords);
      }
      steps.last['tool_sql'] = toolCall.arguments['sql'];
      steps.last['tool_result'] = toolResult;

      history.add(ChatMessage.tool(toolCallId: toolCall.id, content: toolResult));

      // On last allowed iteration, invoke without tools to force a text response
      final forceTextOnly = !_shouldContinue(iterations, stopwatch.elapsed);
      result = await _invokeWithRecording(
        model,
        prompt: PromptValue.chat(history),
        modelName: modelName,
        runId: runId,
        options: forceTextOnly
            ? const ChatGoogleGenerativeAIOptions(tools: [])
            : null,
      );
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
      proposedActions: proposedActions,
      toolCalls: toolCallRecords,
      usage: totalUsage,
    );
  }

  /// Wraps a single `model.invoke()` with a stopwatch and emits a [UsageEvent]
  /// for both success and failure paths. Rethrows the original exception on
  /// failure so the caller's higher-level error handling (in
  /// [AiChatService.sendMessage]) is unchanged.
  static Future<ChatResult> _invokeWithRecording(
    ChatGoogleGenerativeAI model, {
    required PromptValue prompt,
    required String modelName,
    required String runId,
    ChatGoogleGenerativeAIOptions? options,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = options != null
          ? await model
              .invoke(prompt, options: options)
              .timeout(_perInvokeTimeout)
          : await model.invoke(prompt).timeout(_perInvokeTimeout);
      sw.stop();
      final usage = _usageFrom(result);
      await AiGateway.instance.recorder.recordCall(
        callerTag: UsageCallerTags.chat,
        runId: runId,
        provider: UsageProvider.gemini,
        model: modelName,
        kind: UsageKind.chat,
        inputTokens: usage.promptTokens,
        outputTokens: usage.responseTokens,
        totalTokens: usage.totalTokens,
        durationMs: sw.elapsedMilliseconds,
      );
      return result;
    } catch (e) {
      sw.stop();
      final code = e is TimeoutException ? 'timeout' : 'error';
      await AiGateway.instance.recorder.recordCall(
        callerTag: UsageCallerTags.chat,
        runId: runId,
        provider: UsageProvider.gemini,
        model: modelName,
        kind: UsageKind.chat,
        durationMs: sw.elapsedMilliseconds,
        errorCode: code,
      );
      rethrow;
    }
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
    // Every tool (typed query tools + run_sql) routes through the dispatcher.
    // Unknown names come back as a recoverable error so the model self-corrects.
    final result =
        await AiQueryDispatcher.dispatch(toolCall.name, toolCall.arguments);
    final resultToon = toonx.encode(result.toJson());
    records.add(ToolCallRecord(
      id: toolCall.id,
      name: toolCall.name,
      arguments: toolCall.arguments,
      response: resultToon,
    ));
    return resultToon;
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
