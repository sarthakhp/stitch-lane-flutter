import 'dart:convert';

/// Provider that handled the call.
enum UsageProvider { gemini, sarvam }

/// Capability kind — drives which token/timing fields are populated and how
/// cost is computed in [Pricing.estimate].
enum UsageKind {
  /// Pure-text chat completion (langchain-style invoke).
  chat,

  /// Chat completion with non-text content (e.g. audio input → text output).
  multimodal,

  /// Speech-to-text (one-shot or streaming session totals).
  stt,

  /// Text-to-speech (one-shot or streaming session totals).
  tts,
}

/// Stable string IDs used in the `caller_tag` column. Define call sites here
/// instead of stringly-typing them so misspellings don't silently fragment the
/// usage dashboard.
class UsageCallerTags {
  UsageCallerTags._();

  static const chat = 'chat';
  static const orderCreator = 'order_creator';
  static const transcription = 'transcription';
  static const transcriptFormat = 'transcript_format';
  static const sttBatch = 'stt_batch';
  static const sttStream = 'stt_stream';
  static const ttsStream = 'tts_stream';

  static const known = <String>{
    chat,
    orderCreator,
    transcription,
    transcriptFormat,
    sttBatch,
    sttStream,
    ttsStream,
  };
}

/// One billable interaction with an external AI provider.
///
/// Token vs. duration fields are mutually-tolerant: chat calls populate
/// [inputTokens]/[outputTokens]/[totalTokens]; STT/TTS populate audio-duration
/// or character fields. [durationMs] is always wall-clock for the network
/// round-trip(s).
///
/// [runId] groups multiple network calls that logically belong to one
/// user-visible operation (e.g. a single OrderCreatorAgent run that made
/// five invokes). Null for one-shot calls.
class UsageEvent {
  final String id;
  final DateTime occurredAt;
  final String callerTag;
  final String? runId;
  final UsageProvider provider;
  final String model;
  final UsageKind kind;

  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  /// For STT and Gemini multimodal audio input.
  final int? audioInputMs;

  /// For TTS output audio.
  final int? audioOutputMs;

  /// For TTS: characters of text sent in.
  final int? inputChars;

  /// Wall-clock duration for the network round-trip (or the WebSocket
  /// session for streaming providers).
  final int durationMs;

  /// Null when no pricing entry matches `(provider, model, kind)`.
  final double? estimatedCostUsd;

  /// Null on success. Free-form short code on failure ('timeout', 'http_429',
  /// 'parse_error', ...).
  final String? errorCode;

  /// Arbitrary additional data — tool-call counts, iteration counts, etc.
  /// Persisted as JSON in the `meta` column.
  final Map<String, dynamic>? meta;

  const UsageEvent({
    required this.id,
    required this.occurredAt,
    required this.callerTag,
    required this.provider,
    required this.model,
    required this.kind,
    required this.durationMs,
    this.runId,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    this.audioInputMs,
    this.audioOutputMs,
    this.inputChars,
    this.estimatedCostUsd,
    this.errorCode,
    this.meta,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'caller_tag': callerTag,
        'run_id': runId,
        'provider': provider.name,
        'model': model,
        'kind': kind.name,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'total_tokens': totalTokens,
        'audio_input_ms': audioInputMs,
        'audio_output_ms': audioOutputMs,
        'input_chars': inputChars,
        'duration_ms': durationMs,
        'estimated_cost_usd': estimatedCostUsd,
        'error_code': errorCode,
        'meta': meta == null ? null : jsonEncode(meta),
      };

  factory UsageEvent.fromMap(Map<String, dynamic> map) => UsageEvent(
        id: map['id'] as String,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(map['occurred_at'] as int),
        callerTag: map['caller_tag'] as String,
        runId: map['run_id'] as String?,
        provider: UsageProvider.values.byName(map['provider'] as String),
        model: map['model'] as String,
        kind: UsageKind.values.byName(map['kind'] as String),
        inputTokens: map['input_tokens'] as int?,
        outputTokens: map['output_tokens'] as int?,
        totalTokens: map['total_tokens'] as int?,
        audioInputMs: map['audio_input_ms'] as int?,
        audioOutputMs: map['audio_output_ms'] as int?,
        inputChars: map['input_chars'] as int?,
        durationMs: map['duration_ms'] as int,
        estimatedCostUsd: (map['estimated_cost_usd'] as num?)?.toDouble(),
        errorCode: map['error_code'] as String?,
        meta: map['meta'] == null
            ? null
            : jsonDecode(map['meta'] as String) as Map<String, dynamic>,
      );
}

/// Rolled-up totals for a time range and/or a filter (caller_tag, provider).
class UsageSummary {
  final int totalEvents;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalAudioInputMs;
  final int totalAudioOutputMs;
  final int totalInputChars;

  /// Sum of [UsageEvent.estimatedCostUsd] for rows that had a pricing match.
  /// Rows without a pricing entry don't contribute (and are counted in
  /// [eventsMissingCost]).
  final double totalEstimatedCostUsd;
  final int eventsMissingCost;

  const UsageSummary({
    required this.totalEvents,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalAudioInputMs,
    required this.totalAudioOutputMs,
    required this.totalInputChars,
    required this.totalEstimatedCostUsd,
    required this.eventsMissingCost,
  });

  static const zero = UsageSummary(
    totalEvents: 0,
    totalInputTokens: 0,
    totalOutputTokens: 0,
    totalAudioInputMs: 0,
    totalAudioOutputMs: 0,
    totalInputChars: 0,
    totalEstimatedCostUsd: 0,
    eventsMissingCost: 0,
  );
}
