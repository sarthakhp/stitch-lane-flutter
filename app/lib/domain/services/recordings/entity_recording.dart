/// Which domain object a recording is attached to. Drives the source chip and
/// tap-through target in the customer voice-notes timeline.
enum EntityRecordingKind { order, measurement }

extension EntityRecordingKindLabel on EntityRecordingKind {
  String get label {
    switch (this) {
      case EntityRecordingKind.order:
        return 'Order';
      case EntityRecordingKind.measurement:
        return 'Measurement';
    }
  }
}

/// A recording surfaced at the customer level, resolved from a domain row's
/// `audioFilePath` (order or measurement) rather than from the flat audio
/// folder. Carries enough to play it and to navigate back to its source.
class EntityRecording {
  final String filePath;
  final DateTime createdAt;
  final EntityRecordingKind kind;

  /// Id of the source order / measurement, for tap-through navigation.
  final String entityId;

  /// Short human label for the row (e.g. the order title or "Measurement").
  final String label;

  const EntityRecording({
    required this.filePath,
    required this.createdAt,
    required this.kind,
    required this.entityId,
    required this.label,
  });
}
