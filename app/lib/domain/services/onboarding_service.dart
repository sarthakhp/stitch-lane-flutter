import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _backupChoiceKeyPrefix = 'backup_choice_completed_';

  static String _getBackupChoiceKey(String userId) {
    return '$_backupChoiceKeyPrefix$userId';
  }

  static Future<bool> hasCompletedBackupChoice(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_getBackupChoiceKey(userId)) ?? false;
  }

  static Future<void> setBackupChoiceCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getBackupChoiceKey(userId), true);
  }

  static Future<void> clearBackupChoice(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getBackupChoiceKey(userId));
  }
}

