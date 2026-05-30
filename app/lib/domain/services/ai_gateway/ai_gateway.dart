import '../../../backend/repositories/ai_usage_repository.dart';
import 'usage_recorder.dart';

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
