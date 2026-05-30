import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../backend/repositories/ai_usage_repository.dart';
import '../../../utils/app_logger.dart';
import 'pricing.dart';
import 'usage_event.dart';

/// Receives [UsageEvent]s from the gateway and:
///   1. Persists them to SQLite (best-effort — never throws to the caller).
///   2. Re-broadcasts them on a stream, so live UI (e.g. the dashboard) can
///      update without polling the DB.
///
/// Singleton. Initialized once at app startup with a concrete repository.
/// Anything outside the gateway directory should treat this as opaque — emit
/// events via the [AiGateway] facade, not directly here.
class UsageRecorder {
  UsageRecorder._(this._repo);

  static UsageRecorder? _instance;

  /// Wire this up once at startup. Subsequent calls are no-ops.
  static void init(AiUsageRepository repo) {
    _instance ??= UsageRecorder._(repo);
  }

  static UsageRecorder get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'UsageRecorder.init() was never called. Make sure AiGateway is '
        'initialized in main() before any LLM call.',
      );
    }
    return i;
  }

  /// Test/dev escape hatch — replace the singleton with a fresh recorder.
  static void resetForTesting(AiUsageRepository repo) {
    _instance = UsageRecorder._(repo);
  }

  final AiUsageRepository _repo;
  final _uuid = const Uuid();
  final _controller = StreamController<UsageEvent>.broadcast();

  /// Fires every time a new event is recorded. The dashboard subscribes here
  /// to avoid re-querying SQLite on every screen refresh.
  Stream<UsageEvent> get events => _controller.stream;

  /// Persists [event] and broadcasts it. Catches and logs DB errors so a
  /// telemetry failure can never break the user flow.
  Future<void> record(UsageEvent event) async {
    try {
      await _repo.insert(event);
    } catch (e, st) {
      AppLogger.error('UsageRecorder: failed to persist usage event', e, st);
    }
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Convenience builder — most callers will use this rather than constructing
  /// a [UsageEvent] by hand. Computes the cost via [Pricing.estimate] and
  /// fills in id + timestamp.
  Future<UsageEvent> recordCall({
    required String callerTag,
    String? runId,
    required UsageProvider provider,
    required String model,
    required UsageKind kind,
    required int durationMs,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    int? audioInputMs,
    int? audioOutputMs,
    int? inputChars,
    String? errorCode,
    Map<String, dynamic>? meta,
  }) async {
    final cost = errorCode != null
        ? null
        : Pricing.estimate(
            provider: provider,
            model: model,
            kind: kind,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            audioInputMs: audioInputMs,
            audioOutputMs: audioOutputMs,
            inputChars: inputChars,
          );

    final event = UsageEvent(
      id: _uuid.v4(),
      occurredAt: DateTime.now(),
      callerTag: callerTag,
      runId: runId,
      provider: provider,
      model: model,
      kind: kind,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens ??
          ((inputTokens ?? 0) + (outputTokens ?? 0) > 0
              ? (inputTokens ?? 0) + (outputTokens ?? 0)
              : null),
      audioInputMs: audioInputMs,
      audioOutputMs: audioOutputMs,
      inputChars: inputChars,
      durationMs: durationMs,
      estimatedCostUsd: cost,
      errorCode: errorCode,
      meta: meta,
    );

    await record(event);
    return event;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
