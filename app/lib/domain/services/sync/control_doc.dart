class ControlDoc {
  final String writerDeviceId;
  final String writerDeviceName;
  final int epoch;
  final int pendingCount;
  final DateTime? claimedAt;
  final DateTime? updatedAt;

  const ControlDoc({
    required this.writerDeviceId,
    required this.writerDeviceName,
    required this.epoch,
    this.pendingCount = 0,
    this.claimedAt,
    this.updatedAt,
  });

  static ControlDoc? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ControlDoc(
      writerDeviceId: map['writerDeviceId'] as String? ?? '',
      writerDeviceName: map['writerDeviceName'] as String? ?? '',
      epoch: (map['epoch'] as num?)?.toInt() ?? 0,
      pendingCount: (map['pendingCount'] as num?)?.toInt() ?? 0,
      claimedAt: _toDateTime(map['claimedAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'writerDeviceId': writerDeviceId,
    'writerDeviceName': writerDeviceName,
    'epoch': epoch,
    'pendingCount': pendingCount,
    if (claimedAt != null) 'claimedAt': claimedAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  ControlDoc copyWith({
    String? writerDeviceId,
    String? writerDeviceName,
    int? epoch,
    int? pendingCount,
    DateTime? claimedAt,
    DateTime? updatedAt,
  }) =>
      ControlDoc(
        writerDeviceId: writerDeviceId ?? this.writerDeviceId,
        writerDeviceName: writerDeviceName ?? this.writerDeviceName,
        epoch: epoch ?? this.epoch,
        pendingCount: pendingCount ?? this.pendingCount,
        claimedAt: claimedAt ?? this.claimedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
