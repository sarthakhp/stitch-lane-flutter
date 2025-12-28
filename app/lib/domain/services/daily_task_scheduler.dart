import 'package:workmanager/workmanager.dart';
import '../../utils/app_logger.dart';

class DailyTaskScheduler {
  final String taskName;
  final String taskTag;

  const DailyTaskScheduler({
    required this.taskName,
    required this.taskTag,
  });

  Future<void> schedule(String timeString) async {
    await cancel();

    final delay = _calculateDelayUntil(timeString);

    AppLogger.info('[$taskTag] Scheduling task for $timeString (delay: ${delay.inMinutes} minutes)');

    await Workmanager().registerOneOffTask(
      taskName,
      taskName,
      tag: taskTag,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    AppLogger.info('[$taskTag] Task scheduled successfully');
  }

  Future<void> scheduleNextDay(String timeString) async {
    final delay = _calculateDelayForNextDay(timeString);

    AppLogger.info('[$taskTag] Scheduling next day task for $timeString (delay: ${delay.inMinutes} minutes)');

    await Workmanager().registerOneOffTask(
      taskName,
      taskName,
      tag: taskTag,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    AppLogger.info('[$taskTag] Next day task scheduled successfully');
  }

  Future<void> cancel() async {
    await Workmanager().cancelByTag(taskTag);
    AppLogger.info('[$taskTag] Task cancelled');
  }

  Future<void> scheduleTest({int delaySeconds = 15}) async {
    AppLogger.info('[$taskTag] Scheduling test task with delay: $delaySeconds seconds');

    await Workmanager().registerOneOffTask(
      '$taskName.test',
      taskName,
      initialDelay: Duration(seconds: delaySeconds),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    AppLogger.info('[$taskTag] Test task scheduled, should trigger in $delaySeconds seconds');
  }

  Duration _calculateDelayUntil(String timeString) {
    final scheduledTime = _parseTimeString(timeString);
    final now = DateTime.now();
    var nextRun = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    if (nextRun.isBefore(now) || nextRun.isAtSameMomentAs(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    return nextRun.difference(now);
  }

  Duration _calculateDelayForNextDay(String timeString) {
    final scheduledTime = _parseTimeString(timeString);
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final nextRun = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    return nextRun.difference(now);
  }

  DateTime _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(2000, 1, 1, hour, minute);
  }
}

