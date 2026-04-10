import '../../utils/app_logger.dart';
import 'sqlite_database.dart';

class DatabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SqliteDatabase.database;
      AppLogger.info('DatabaseService: SQLite initialized');
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  static Future<void> close() async {
    await SqliteDatabase.close();
    _initialized = false;
  }
}
