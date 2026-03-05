import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_logger.dart';

class LogManagerService {
  static Future<String?> getLogsFromLastMinutes(int minutes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        try {
          AppLogger.warning('Logs directory does not exist');
        } catch (_) {
          // Silently fail if logging fails
        }
        return null;
      }

      final logFile = File('${logsDir.path}/app_logs.txt');
      final oldLogFile = File('${logsDir.path}/app_logs_old.txt');

      final cutoffTime = DateTime.now().subtract(Duration(minutes: minutes));
      final filteredLogs = StringBuffer();
      int logCount = 0;

      for (final file in [logFile, oldLogFile]) {
        try {
          if (await file.exists()) {
            final lines = await file.readAsLines();

            for (final line in lines) {
              try {
                final timestamp = _extractTimestamp(line);
                if (timestamp != null && timestamp.isAfter(cutoffTime)) {
                  filteredLogs.writeln(line);
                  logCount++;
                }
              } catch (_) {
                // Skip malformed log lines
                continue;
              }
            }
          }
        } catch (_) {
          // Skip files that can't be read
          continue;
        }
      }

      if (logCount == 0) {
        return null;
      }

      try {
        AppLogger.info('Collected $logCount log entries from last $minutes minutes');
      } catch (_) {
        // Silently fail if logging fails
      }
      return filteredLogs.toString();
    } catch (e) {
      try {
        AppLogger.error('Failed to get logs', e);
      } catch (_) {
        // Silently fail if logging fails
      }
      return null;
    }
  }

  static DateTime? _extractTimestamp(String logLine) {
    try {
      final startIndex = logLine.indexOf('[');
      final endIndex = logLine.indexOf(']');
      
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        return null;
      }
      
      final timestampStr = logLine.substring(startIndex + 1, endIndex);
      return DateTime.parse(timestampStr);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> shareLogsAsFile({int minutes = 30}) async {
    try {
      final logsContent = await getLogsFromLastMinutes(minutes);

      if (logsContent == null || logsContent.isEmpty) {
        try {
          AppLogger.warning('No logs found to share');
        } catch (_) {
          // Silently fail if logging fails
        }
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final logFileName = 'stitch_lane_logs_$timestamp.txt';
      final logFile = File('${tempDir.path}/$logFileName');

      await logFile.writeAsString(logsContent);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(logFile.path)],
          subject: 'Stitch Lane App Logs (Last $minutes minutes)',
          text: 'App logs from the last $minutes minutes',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        try {
          AppLogger.info('Logs shared successfully');
        } catch (_) {
          // Silently fail if logging fails
        }
        return true;
      } else {
        try {
          AppLogger.warning('Logs sharing was dismissed or failed');
        } catch (_) {
          // Silently fail if logging fails
        }
        return false;
      }
    } catch (e) {
      try {
        AppLogger.error('Failed to share logs', e);
      } catch (_) {
        // Silently fail if logging fails
      }
      return false;
    }
  }

  static Future<int> getLogFileSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      final logFile = File('${logsDir.path}/app_logs.txt');
      final oldLogFile = File('${logsDir.path}/app_logs_old.txt');

      try {
        if (await logFile.exists()) {
          totalSize += await logFile.length();
        }
      } catch (_) {
        // Skip if file can't be read
      }

      try {
        if (await oldLogFile.exists()) {
          totalSize += await oldLogFile.length();
        }
      } catch (_) {
        // Skip if file can't be read
      }

      return totalSize;
    } catch (e) {
      // Return 0 if anything fails
      return 0;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

