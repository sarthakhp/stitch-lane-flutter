import 'dart:convert';
import 'dart:io';

/// Which voice flow produced a recording. Drives the source chip in the
/// Recordings debugger.
enum RecordingSource { orderCreator, measurement, assistant, unknown }

extension RecordingSourceLabel on RecordingSource {
  String get label {
    switch (this) {
      case RecordingSource.orderCreator:
        return 'Create Order';
      case RecordingSource.measurement:
        return 'Measurement';
      case RecordingSource.assistant:
        return 'AI Assistant';
      case RecordingSource.unknown:
        return 'Voice';
    }
  }
}

/// Sidecar metadata stored as `<stem>.json` next to a recording's `<stem>.wav`
/// in the audio-backups directory. Correlates the audio with what was said
/// (transcript) and what the AI did (actions), so the Recordings debugger can
/// answer "she said X, the AI did Y" without grepping logs.
class RecordingMetadata {
  static const int currentVersion = 1;

  final int version;
  final DateTime createdAt;
  final RecordingSource source;

  /// Short label — usually the customer name.
  final String? title;

  /// What was said (transcript captured at the time).
  final String? transcript;

  /// Human-readable bullets of what the AI did / the outcome of this recording.
  final List<String> actions;

  RecordingMetadata({
    required this.source,
    DateTime? createdAt,
    this.title,
    this.transcript,
    this.actions = const [],
    this.version = currentVersion,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'version': version,
        'created_at': createdAt.toIso8601String(),
        'source': source.name,
        'title': title,
        'transcript': transcript,
        'actions': actions,
      };

  factory RecordingMetadata.fromJson(Map<String, dynamic> json) {
    return RecordingMetadata(
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      source: RecordingSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => RecordingSource.unknown,
      ),
      title: json['title'] as String?,
      transcript: json['transcript'] as String?,
      actions: (json['actions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  String encode() => jsonEncode(toJson());

  static RecordingMetadata decode(String s) =>
      RecordingMetadata.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// One recording surfaced in the browser: the playable WAV plus its computed
/// size / duration and (optional) sidecar metadata.
class RecordingEntry {
  final File wav;
  final DateTime createdAt;
  final int sizeBytes;
  final Duration duration;
  final RecordingMetadata? meta;

  RecordingEntry({
    required this.wav,
    required this.createdAt,
    required this.sizeBytes,
    required this.duration,
    required this.meta,
  });

  RecordingSource get source => meta?.source ?? RecordingSource.unknown;
}
