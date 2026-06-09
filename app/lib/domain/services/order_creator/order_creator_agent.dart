import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:uuid/uuid.dart';

import '../../../backend/models/customer.dart';
import '../../models/order_proposal.dart';
import '../../../utils/app_logger.dart';
import '../ai_chat_config.dart';
import '../ai_chat_models.dart';
import '../ai_gateway/ai_error.dart';
import '../ai_gateway/ai_gateway.dart';
import '../ai_gateway/usage_event.dart';
import 'order_creator_prompts.dart';
import 'order_creator_tools.dart';

/// One thing the tailor said during a session, in order. Fed back to the agent
/// as a reference log so a refinement turn can resolve references to earlier
/// turns ("the lining I mentioned", "make the first one red too") even though
/// the prior wording isn't in the model's chat history (each turn is stateless;
/// the draft is the source of truth, this is reference context).
class CreatorUtterance {
  /// false = the initial voice dump; true = a later refinement instruction.
  final bool isFeedback;
  final String text;
  const CreatorUtterance({required this.isFeedback, required this.text});
}

/// One outcome of [OrderCreatorAgent.run].
class OrderCreatorAgentResult {
  final OrderProposalDraft draft;
  final String? commentary;
  final int iterations;
  final bool stoppedEarly;
  final AiTokenUsage usage;
  final String? errorMessage;

  OrderCreatorAgentResult({
    required this.draft,
    required this.commentary,
    required this.iterations,
    required this.stoppedEarly,
    required this.usage,
    this.errorMessage,
  });

  bool get failed => errorMessage != null;
}

/// Stateless Gemini-powered agent that turns a voice-dump (and optional
/// feedback) into a [OrderProposalDraft] via a tool-calling loop.
///
/// Design notes:
/// - The DRAFT state lives outside this class. We accept it on input and
///   return the new draft on output. No fields, no caches.
/// - The model is given exactly the 6 mutation tools declared in
///   [OrderCreatorTools]. The loop terminates when the model emits text
///   without function calls (natural termination, Claude-style).
/// - Safety: max iterations + wall-clock + per-invoke timeout.
class OrderCreatorAgent {
  static const _maxIterations = 12;
  static const _maxExecutionTime = Duration(seconds: 90);
  static const _perInvokeTimeout = Duration(seconds: 45);

  final String modelName;

  OrderCreatorAgent({this.modelName = defaultAiChatModel});

  /// Run one turn. Pass [transcript] for the initial dump or [feedback] for
  /// a refinement turn (or both, though usually only one is non-empty).
  Future<OrderCreatorAgentResult> run({
    required Customer customer,
    required OrderProposalDraft draft,
    String transcript = '',
    String feedback = '',
    List<CreatorUtterance> conversation = const [],
    void Function(AgentLogEntry)? onLog,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      const message = 'GEMINI_API_KEY missing — set it in .env to use the AI flow.';
      onLog?.call(AgentLogEntry(kind: AgentLogKind.error, label: message));
      return OrderCreatorAgentResult(
        draft: draft,
        commentary: null,
        iterations: 0,
        stoppedEarly: true,
        usage: AiTokenUsage.zero,
        errorMessage: message,
      );
    }

    final tools = OrderCreatorTools(initial: draft);

    final model = ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: ChatGoogleGenerativeAIOptions(
        model: modelName,
        tools: OrderCreatorTools.specs,
      ),
    );

    final systemPrompt = OrderCreatorPrompts.build(
      customerName: customer.name,
      draftJson: jsonEncode(tools.draft.toJson()),
      conversation: _conversationBlock(conversation),
    );

    final userMessage = _buildUserMessage(transcript: transcript, feedback: feedback);
    if (userMessage.isEmpty) {
      const message = 'Nothing to send to the agent — no transcript or feedback.';
      onLog?.call(AgentLogEntry(kind: AgentLogKind.error, label: message));
      return OrderCreatorAgentResult(
        draft: draft,
        commentary: null,
        iterations: 0,
        stoppedEarly: true,
        usage: AiTokenUsage.zero,
        errorMessage: message,
      );
    }

    final history = <ChatMessage>[
      ChatMessage.system(systemPrompt),
      ChatMessage.humanText(userMessage),
    ];

    // Shared across every model.invoke() emitted by this run, so the
    // dashboard can roll up "what did this one order-creation cost".
    final runId = const Uuid().v4();

    var totalUsage = AiTokenUsage.zero;
    var iterations = 0;
    final stopwatch = Stopwatch()..start();

    try {
      var result = await _invokeWithRecording(
        model,
        prompt: PromptValue.chat(history),
        runId: runId,
      );
      totalUsage = totalUsage + _usageFrom(result);
      var aiMessage = result.output;
      history.add(aiMessage);

      while (aiMessage.toolCalls.isNotEmpty &&
          _shouldContinue(iterations, stopwatch.elapsed)) {
        iterations++;
        for (final call in aiMessage.toolCalls) {
          onLog?.call(AgentLogEntry(
            kind: AgentLogKind.toolCall,
            label: call.name,
            data: call.arguments,
          ));

          final toolResult = tools.dispatch(call.name, call.arguments);

          onLog?.call(AgentLogEntry(
            kind: AgentLogKind.toolResult,
            label: call.name,
            data: toolResult,
          ));

          history.add(ChatMessage.tool(
            toolCallId: call.id,
            content: jsonEncode(toolResult),
          ));
        }

        // On the last allowed iteration force a text-only response so we
        // can still surface a final commentary to the user.
        final forceTextOnly = !_shouldContinue(iterations, stopwatch.elapsed);
        result = await _invokeWithRecording(
          model,
          prompt: PromptValue.chat(history),
          runId: runId,
          options: forceTextOnly
              ? const ChatGoogleGenerativeAIOptions(tools: [])
              : null,
        );
        totalUsage = totalUsage + _usageFrom(result);
        aiMessage = result.output;
        history.add(aiMessage);
      }

      clearThoughtSignatureCache();

      final stoppedEarly = aiMessage.toolCalls.isNotEmpty;
      final commentary = aiMessage.content.trim();

      if (commentary.isNotEmpty) {
        onLog?.call(AgentLogEntry(
          kind: AgentLogKind.agentText,
          label: commentary,
        ));
      }

      _logExchange(
        customer: customer.name,
        userMessage: userMessage,
        startDraft: draft,
        endDraft: tools.draft,
        iterations: iterations,
        usage: totalUsage,
        stoppedEarly: stoppedEarly,
        commentary: commentary,
      );

      return OrderCreatorAgentResult(
        draft: tools.draft,
        commentary: commentary.isEmpty ? null : commentary,
        iterations: iterations,
        stoppedEarly: stoppedEarly,
        usage: totalUsage,
      );
    } catch (e, st) {
      AppLogger.error('OrderCreatorAgent: turn failed', e, st);
      onLog?.call(AgentLogEntry(
        kind: AgentLogKind.error,
        label: 'Agent error: $e',
      ));
      return OrderCreatorAgentResult(
        draft: tools.draft, // partial mutations still useful
        commentary: null,
        iterations: iterations,
        stoppedEarly: true,
        usage: totalUsage,
        // User-facing reason (out of credits, offline, …); the raw error is in
        // the activity log above and the debug log for developers.
        errorMessage: describeAiError(e),
      );
    }
  }

  /// Mirror of [AiExecutor._invokeWithRecording] — stopwatch + emit a
  /// [UsageEvent] on both success and failure, then rethrow on failure so
  /// the surrounding try/catch in [run] continues to drive UX state.
  Future<ChatResult> _invokeWithRecording(
    ChatGoogleGenerativeAI model, {
    required PromptValue prompt,
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
        callerTag: UsageCallerTags.orderCreator,
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
        callerTag: UsageCallerTags.orderCreator,
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

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Numbered reference log of everything said this session. Returns null on
  /// the very first turn (nothing prior to reference yet — saves tokens).
  String? _conversationBlock(List<CreatorUtterance> conversation) {
    if (conversation.length <= 1) return null;
    final lines = <String>[];
    for (var i = 0; i < conversation.length; i++) {
      final u = conversation[i];
      lines.add('${i + 1}. (${u.isFeedback ? 'feedback' : 'dump'}) ${u.text}');
    }
    return lines.join('\n');
  }

  String _buildUserMessage({required String transcript, required String feedback}) {
    final t = transcript.trim();
    final f = feedback.trim();
    if (t.isEmpty && f.isEmpty) return '';
    if (t.isNotEmpty && f.isEmpty) {
      return 'Voice dump transcript:\n$t';
    }
    if (t.isEmpty && f.isNotEmpty) {
      return 'Refinement feedback from the tailor:\n$f';
    }
    return 'Voice dump transcript:\n$t\n\nAdditional instruction:\n$f';
  }

  bool _shouldContinue(int iterations, Duration elapsed) {
    return iterations < _maxIterations && elapsed < _maxExecutionTime;
  }

  AiTokenUsage _usageFrom(ChatResult result) => AiTokenUsage(
        promptTokens: result.usage.promptTokens ?? 0,
        responseTokens: result.usage.responseTokens ?? 0,
        totalTokens: result.usage.totalTokens ?? 0,
      );

  void _logExchange({
    required String customer,
    required String userMessage,
    required OrderProposalDraft startDraft,
    required OrderProposalDraft endDraft,
    required int iterations,
    required AiTokenUsage usage,
    required bool stoppedEarly,
    required String commentary,
  }) {
    final log = {
      'agent': 'OrderCreatorAgent',
      'customer': customer,
      'user': userMessage,
      'start_draft': startDraft.toJson(),
      'end_draft': endDraft.toJson(),
      'iterations': iterations,
      'stopped_early': stoppedEarly,
      'commentary': commentary,
      'tokens': {
        'in': usage.promptTokens,
        'out': usage.responseTokens,
        'total': usage.totalTokens,
      },
    };
    final encoded = jsonEncode(log);
    const chunk = 800;
    for (var i = 0; i < encoded.length; i += chunk) {
      final end = (i + chunk < encoded.length) ? i + chunk : encoded.length;
      AppLogger.info(
        '${i == 0 ? "ORDER_AGENT" : "ORDER_AGENT+"}: ${encoded.substring(i, end)}',
      );
    }
  }
}
