import 'package:workmanager/workmanager.dart';
import '../../utils/app_logger.dart';

class BackgroundTaskDispatcher {
  static Future<void> initialize(void Function() callbackDispatcher) async {
    await Workmanager().initialize(callbackDispatcher);
    AppLogger.info('BackgroundTaskDispatcher initialized');
  }
}

