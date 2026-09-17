import '../../../backend/repositories/ai_usage_repository.dart';
import 'ai_kill_switch.dart';
import 'usage_recorder.dart';

/// Thrown by [AiGateway.checkEnabled] when the remote kill switch has
/// disabled AI features. Call sites should catch this and show the same
/// "AI temporarily unavailable" affordance, rather than letting it surface
/// as a generic network/provider error.
class AiDisabledException implements Exception {
  const AiDisabledException();

  @override
  String toString() => 'AiDisabledException: AI features are currently disabled';
}

/// Single entry point for every external AI provider call in the app.
///
/// **Phase 1 (this file's current state):** the gateway exposes the
/// [UsageRecorder] so call sites can opt-in to instrumentation without
/// changing their SDK code. Adapters that actually own the SDK call (so
/// callers never touch `ChatGoogleGenerativeAI` / `GoogleAIClient` / `http`
/// directly) land in phase 2 as we migrate each existing call site.
///
/// At that point, methods like:
///
///   `Future<ChatResult> chatInvoke(ChatInvokeRequest req)`
///   `Future<MultimodalResult> multimodalGenerate(MultimodalRequest req)`
///   `Future<String?> sttBatch(SttBatchRequest req)`
///   `InstrumentedSttSession openSttStream(...)`
///   `InstrumentedTtsSession openTtsStream(...)`
///
/// will appear here, each routing through a port → adapter, wrapped by a
/// stopwatch + [UsageRecorder.recordCall] in one shared place.
class AiGateway {
  AiGateway._();
  static final AiGateway instance = AiGateway._();

  bool _initialized = false;

  /// Call once at app boot, after SQLite is ready and before any LLM call.
  /// Currently just wires up the [UsageRecorder] with the SQLite-backed
  /// repository.
  void init({AiUsageRepository? repository}) {
    if (_initialized) return;
    UsageRecorder.init(repository ?? AiUsageRepository());
    _initialized = true;
  }

  /// Direct access to the recorder for callers that still own their SDK call
  /// but want to log usage. Phase 2 will replace most of these with full
  /// gateway methods, but exposing this now lets us start collecting data
  /// against existing code paths with minimal churn.
  UsageRecorder get recorder => UsageRecorder.instance;

  /// Whether AI features are currently allowed to run, per the remote kill
  /// switch (see [AiKillSwitch]). Every call site that invokes an AI
  /// provider directly (until the phase-2 methods above land) should check
  /// this — or call [checkEnabled] — before making the call.
  bool get isEnabled => AiKillSwitch.enabled;

  /// Throws [AiDisabledException] if the kill switch has disabled AI.
  /// Call at the top of any AI call site as a cheap pre-flight guard.
  void checkEnabled() {
    if (!isEnabled) throw const AiDisabledException();
  }

  // ---------------------------------------------------------------------------
  // Phase 2 method stubs — kept as commented signatures so reviewers can see
  // the planned shape without depending on adapters that don't exist yet.
  //
  // Future<ChatResult> chatInvoke(ChatInvokeRequest req);
  // Future<String?> multimodalGenerate(MultimodalRequest req);
  // Future<String?> sttBatch(SttBatchRequest req);
  // InstrumentedSttSession openSttStream(SttStreamConfig cfg);
  // InstrumentedTtsSession openTtsStream(TtsStreamConfig cfg);
  // ---------------------------------------------------------------------------
}
