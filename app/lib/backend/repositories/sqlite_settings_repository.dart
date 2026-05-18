import 'package:sqflite/sqflite.dart';
import '../models/app_settings.dart';
import '../database/sqlite_database.dart';
import '../../constants/app_constants.dart';
import 'settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<AppSettings> getSettings() async {
    try {
      final db = await _db;
      final maps = await db.query('settings',
          where: 'key = ?', whereArgs: [AppConstants.settingsKey]);
      if (maps.isEmpty) return AppSettings();
      return fromMap(maps.first);
    } catch (e) {
      throw Exception('Failed to get settings: $e');
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final db = await _db;
      await db.insert('settings', toMap(settings),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _db;
      await db.delete('settings');
    } catch (e) {
      throw Exception('Failed to clear settings: $e');
    }
  }

  static Map<String, dynamic> toMap(AppSettings s) => {
        'key': AppConstants.settingsKey,
        'due_date_warning_threshold': s.dueDateWarningThreshold,
        'pending_orders_reminder_enabled': s.pendingOrdersReminderEnabled ? 1 : 0,
        'pending_orders_reminder_time': s.pendingOrdersReminderTime,
        'auto_backup_enabled': s.autoBackupEnabled ? 1 : 0,
        'auto_backup_time': s.autoBackupTime,
        'last_backup_time': s.lastBackupTime?.toIso8601String(),
        'debug_logs_enabled': s.debugLogsEnabled ? 1 : 0,
        'ai_chat_model': s.aiChatModelRaw,
        'ai_voice_model': s.aiVoiceModelRaw,
        'last_backup_status': s.lastBackupStatus,
        'last_backup_error': s.lastBackupError,
        'stt_provider': s.sttProviderRaw,
      };

  static AppSettings fromMap(Map<String, dynamic> map) => AppSettings(
        dueDateWarningThreshold: map['due_date_warning_threshold'] as int? ?? 3,
        pendingOrdersReminderEnabledRaw:
            (map['pending_orders_reminder_enabled'] as int? ?? 0) == 1,
        pendingOrdersReminderTimeRaw:
            map['pending_orders_reminder_time'] as String?,
        autoBackupEnabledRaw: (map['auto_backup_enabled'] as int? ?? 0) == 1,
        autoBackupTimeRaw: map['auto_backup_time'] as String?,
        lastBackupTime: map['last_backup_time'] != null
            ? DateTime.parse(map['last_backup_time'] as String)
            : null,
        debugLogsEnabledRaw: (map['debug_logs_enabled'] as int? ?? 0) == 1,
        aiChatModelRaw: map['ai_chat_model'] as String?,
        aiVoiceModelRaw: map['ai_voice_model'] as String?,
        lastBackupStatus: map['last_backup_status'] as String?,
        lastBackupError: map['last_backup_error'] as String?,
        sttProviderRaw: map['stt_provider'] as String?,
      );
}
