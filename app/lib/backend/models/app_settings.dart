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
  final DateTime? lastBackupTime;

  @HiveField(6)
  final bool? debugLogsEnabledRaw;

  @HiveField(7)
  final String? aiChatModelRaw;

  @HiveField(8)
  final String? aiVoiceModelRaw;

  bool get pendingOrdersReminderEnabled => pendingOrdersReminderEnabledRaw ?? false;
  String get pendingOrdersReminderTime => pendingOrdersReminderTimeRaw ?? '08:30';
  bool get autoBackupEnabled => autoBackupEnabledRaw ?? false;
  String get autoBackupTime => autoBackupTimeRaw ?? '03:00';
  bool get debugLogsEnabled => debugLogsEnabledRaw ?? false;
  String get aiChatModel => aiChatModelRaw ?? 'gemini-3.1-flash-lite-preview';
  String get aiVoiceModel => aiVoiceModelRaw ?? 'gemini-2.5-flash-lite';

  AppSettings({
    this.dueDateWarningThreshold = 3,
    this.pendingOrdersReminderEnabledRaw,
    this.pendingOrdersReminderTimeRaw,
    this.autoBackupEnabledRaw,
    this.autoBackupTimeRaw,
    this.lastBackupTime,
    this.debugLogsEnabledRaw,
    this.aiChatModelRaw,
    this.aiVoiceModelRaw,
  });

  AppSettings copyWith({
    int? dueDateWarningThreshold,
    bool? pendingOrdersReminderEnabled,
    String? pendingOrdersReminderTime,
    bool? autoBackupEnabled,
    String? autoBackupTime,
    DateTime? lastBackupTime,
    bool? debugLogsEnabled,
    String? aiChatModel,
    String? aiVoiceModel,
  }) {
    return AppSettings(
      dueDateWarningThreshold: dueDateWarningThreshold ?? this.dueDateWarningThreshold,
      pendingOrdersReminderEnabledRaw: pendingOrdersReminderEnabled ?? this.pendingOrdersReminderEnabled,
      pendingOrdersReminderTimeRaw: pendingOrdersReminderTime ?? this.pendingOrdersReminderTime,
      autoBackupEnabledRaw: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupTimeRaw: autoBackupTime ?? this.autoBackupTime,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      debugLogsEnabledRaw: debugLogsEnabled ?? this.debugLogsEnabled,
      aiChatModelRaw: aiChatModel ?? aiChatModelRaw,
      aiVoiceModelRaw: aiVoiceModel ?? aiVoiceModelRaw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dueDateWarningThreshold': dueDateWarningThreshold,
      'pendingOrdersReminderEnabled': pendingOrdersReminderEnabled,
      'pendingOrdersReminderTime': pendingOrdersReminderTime,
      'autoBackupEnabled': autoBackupEnabled,
      'autoBackupTime': autoBackupTime,
      'lastBackupTime': lastBackupTime?.toIso8601String(),
      'debugLogsEnabled': debugLogsEnabled,
      'aiChatModel': aiChatModelRaw,
      'aiVoiceModel': aiVoiceModelRaw,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    DateTime? backupTime;
    if (json['lastBackupTime'] != null) {
      backupTime = DateTime.parse(json['lastBackupTime'] as String);
    } else if (json['lastAutoBackupTime'] != null) {
      backupTime = DateTime.parse(json['lastAutoBackupTime'] as String);
    }

    return AppSettings(
      dueDateWarningThreshold: json['dueDateWarningThreshold'] as int? ?? 3,
      pendingOrdersReminderEnabledRaw: json['pendingOrdersReminderEnabled'] as bool?,
      pendingOrdersReminderTimeRaw: json['pendingOrdersReminderTime'] as String?,
      autoBackupEnabledRaw: json['autoBackupEnabled'] as bool?,
      autoBackupTimeRaw: json['autoBackupTime'] as String?,
      lastBackupTime: backupTime,
      debugLogsEnabledRaw: json['debugLogsEnabled'] as bool?,
      aiChatModelRaw: json['aiChatModel'] as String?,
      aiVoiceModelRaw: json['aiVoiceModel'] as String?,
    );
  }

  @override
  String toString() {
    return 'AppSettings(dueDateWarningThreshold: $dueDateWarningThreshold, pendingOrdersReminderEnabled: $pendingOrdersReminderEnabled, pendingOrdersReminderTime: $pendingOrdersReminderTime, autoBackupEnabled: $autoBackupEnabled, autoBackupTime: $autoBackupTime, lastBackupTime: $lastBackupTime, debugLogsEnabled: $debugLogsEnabled, aiChatModel: $aiChatModel, aiVoiceModel: $aiVoiceModel)';
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
           other.lastBackupTime == lastBackupTime &&
           other.debugLogsEnabled == debugLogsEnabled &&
           other.aiChatModelRaw == aiChatModelRaw &&
           other.aiVoiceModelRaw == aiVoiceModelRaw;
  }

  @override
  int get hashCode => Object.hash(
    dueDateWarningThreshold,
    pendingOrdersReminderEnabled,
    pendingOrdersReminderTime,
    autoBackupEnabled,
    autoBackupTime,
    lastBackupTime,
    debugLogsEnabled,
    aiChatModelRaw,
    aiVoiceModelRaw,
  );
}

