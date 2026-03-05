import 'package:logger/logger.dart';
import 'file_log_output.dart';

class AppLogger {
  static Logger? _logger;
  static bool _fileLoggingEnabled = false;

  static Logger get logger {
    if (_logger == null) {
      _initializeLogger();
    }
    return _logger!;
  }

  static void _initializeLogger() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _fileLoggingEnabled ? MultiOutput([ConsoleOutput(), FileLogOutput()]) : null,
    );
  }

  static Future<void> enableFileLogging() async {
    try {
      if (_fileLoggingEnabled) return;

      _fileLoggingEnabled = true;
      await FileLogOutput.initialize();
      _initializeLogger();

      try {
        info('File logging enabled');
      } catch (_) {
        // Silently fail if logging the enable message fails
      }
    } catch (e) {
      _fileLoggingEnabled = false;
      _initializeLogger();
      try {
        warning('Failed to enable file logging: $e');
      } catch (_) {
        // Silently fail - don't let logging errors affect the app
      }
    }
  }

  static void disableFileLogging() {
    try {
      if (!_fileLoggingEnabled) return;

      _fileLoggingEnabled = false;
      _initializeLogger();

      try {
        info('File logging disabled');
      } catch (_) {
        // Silently fail if logging the disable message fails
      }
    } catch (e) {
      try {
        warning('Failed to disable file logging: $e');
      } catch (_) {
        // Silently fail - don't let logging errors affect the app
      }
    }
  }

  static bool get isFileLoggingEnabled => _fileLoggingEnabled;

  static Future<void> clearLogs() async {
    try {
      await FileLogOutput.clearLogs();
      try {
        info('Logs cleared');
      } catch (_) {
        // Silently fail if logging the clear message fails
      }
    } catch (e) {
      try {
        warning('Failed to clear logs: $e');
      } catch (_) {
        // Silently fail - don't let logging errors affect the app
      }
    }
  }

  static void debug(String message) {
    try {
      logger.d(message);
    } catch (_) {
      // Silently fail - don't let logging errors affect the app
    }
  }

  static void info(String message) {
    try {
      logger.i(message);
    } catch (_) {
      // Silently fail - don't let logging errors affect the app
    }
  }

  static void warning(String message) {
    try {
      logger.w(message);
    } catch (_) {
      // Silently fail - don't let logging errors affect the app
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    try {
      logger.e(message, error: error, stackTrace: stackTrace);
    } catch (_) {
      // Silently fail - don't let logging errors affect the app
    }
  }
}

