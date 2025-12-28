import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
class AppSettings {
  @HiveField(0)
  final int dueDateWarningThreshold;

  @HiveField(1)
  final bool? pendingOrdersReminderEnabledRaw;

  @HiveField(2)
  final String? pendingOrdersReminderTimeRaw;

  @HiveField(3)
  final bool? autoBackupEnabledRaw;

  @HiveField(4)
  final String? autoBackupTimeRaw;

  @HiveField(5)
  final DateTime? lastAutoBackupTime;

  bool get pendingOrdersReminderEnabled => pendingOrdersReminderEnabledRaw ?? false;
  String get pendingOrdersReminderTime => pendingOrdersReminderTimeRaw ?? '08:30';
  bool get autoBackupEnabled => autoBackupEnabledRaw ?? false;
  String get autoBackupTime => autoBackupTimeRaw ?? '03:00';

  AppSettings({
    this.dueDateWarningThreshold = 3,
    this.pendingOrdersReminderEnabledRaw,
    this.pendingOrdersReminderTimeRaw,
    this.autoBackupEnabledRaw,
    this.autoBackupTimeRaw,
    this.lastAutoBackupTime,
  });

  AppSettings copyWith({
    int? dueDateWarningThreshold,
    bool? pendingOrdersReminderEnabled,
    String? pendingOrdersReminderTime,
    bool? autoBackupEnabled,
    String? autoBackupTime,
    DateTime? lastAutoBackupTime,
  }) {
    return AppSettings(
      dueDateWarningThreshold: dueDateWarningThreshold ?? this.dueDateWarningThreshold,
      pendingOrdersReminderEnabledRaw: pendingOrdersReminderEnabled ?? this.pendingOrdersReminderEnabled,
      pendingOrdersReminderTimeRaw: pendingOrdersReminderTime ?? this.pendingOrdersReminderTime,
      autoBackupEnabledRaw: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupTimeRaw: autoBackupTime ?? this.autoBackupTime,
      lastAutoBackupTime: lastAutoBackupTime ?? this.lastAutoBackupTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dueDateWarningThreshold': dueDateWarningThreshold,
      'pendingOrdersReminderEnabled': pendingOrdersReminderEnabled,
      'pendingOrdersReminderTime': pendingOrdersReminderTime,
      'autoBackupEnabled': autoBackupEnabled,
      'autoBackupTime': autoBackupTime,
      'lastAutoBackupTime': lastAutoBackupTime?.toIso8601String(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      dueDateWarningThreshold: json['dueDateWarningThreshold'] as int? ?? 3,
      pendingOrdersReminderEnabledRaw: json['pendingOrdersReminderEnabled'] as bool?,
      pendingOrdersReminderTimeRaw: json['pendingOrdersReminderTime'] as String?,
      autoBackupEnabledRaw: json['autoBackupEnabled'] as bool?,
      autoBackupTimeRaw: json['autoBackupTime'] as String?,
      lastAutoBackupTime: json['lastAutoBackupTime'] != null
          ? DateTime.parse(json['lastAutoBackupTime'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'AppSettings(dueDateWarningThreshold: $dueDateWarningThreshold, pendingOrdersReminderEnabled: $pendingOrdersReminderEnabled, pendingOrdersReminderTime: $pendingOrdersReminderTime, autoBackupEnabled: $autoBackupEnabled, autoBackupTime: $autoBackupTime, lastAutoBackupTime: $lastAutoBackupTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
           other.dueDateWarningThreshold == dueDateWarningThreshold &&
           other.pendingOrdersReminderEnabled == pendingOrdersReminderEnabled &&
           other.pendingOrdersReminderTime == pendingOrdersReminderTime &&
           other.autoBackupEnabled == autoBackupEnabled &&
           other.autoBackupTime == autoBackupTime &&
           other.lastAutoBackupTime == lastAutoBackupTime;
  }

  @override
  int get hashCode => Object.hash(
    dueDateWarningThreshold,
    pendingOrdersReminderEnabled,
    pendingOrdersReminderTime,
    autoBackupEnabled,
    autoBackupTime,
    lastAutoBackupTime,
  );
}

