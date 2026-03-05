import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class FileLogOutput extends LogOutput {
  static File? _logFile;
  static bool _isInitialized = false;
  static bool _initializationFailed = false;
  static const int _maxLogFileSize = 5 * 1024 * 1024;

  static Future<void> initialize() async {
    if (_isInitialized || _initializationFailed) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      _logFile = File('${logsDir.path}/app_logs.txt');

      if (await _logFile!.exists()) {
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFile();
        }
      }

      _isInitialized = true;
    } catch (e) {
      _initializationFailed = true;
      _isInitialized = false;
      _logFile = null;
      try {
        debugPrint('Failed to initialize file log output: $e');
      } catch (_) {
        // Silently fail - don't let logging errors affect the app
      }
    }
  }

  static Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      final oldLogFile = File('${logsDir.path}/app_logs_old.txt');

      if (await oldLogFile.exists()) {
        await oldLogFile.delete();
      }

      await _logFile!.rename(oldLogFile.path);
      _logFile = File('${logsDir.path}/app_logs.txt');
    } catch (e) {
      try {
        debugPrint('Failed to rotate log file: $e');
      } catch (_) {
        // Silently fail
      }
    }
  }

  static Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
      }

      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      final oldLogFile = File('${logsDir.path}/app_logs_old.txt');

      if (await oldLogFile.exists()) {
        await oldLogFile.delete();
      }

      _isInitialized = false;
      _initializationFailed = false;
      await initialize();
    } catch (e) {
      try {
        debugPrint('Failed to clear logs: $e');
      } catch (_) {
        // Silently fail
      }
    }
  }

  static Future<String?> getLogsDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/logs';
    } catch (e) {
      return null;
    }
  }

  @override
  void output(OutputEvent event) {
    if (_logFile == null || !_isInitialized) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final buffer = StringBuffer();

      for (var line in event.lines) {
        buffer.writeln('[$timestamp] $line');
      }

      _logFile!.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      try {
        debugPrint('Failed to write to log file: $e');
      } catch (_) {
        // Silently fail - don't let logging errors affect the app
      }
    }
  }
}

