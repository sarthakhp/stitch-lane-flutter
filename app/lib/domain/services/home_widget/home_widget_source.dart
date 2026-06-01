import 'package:home_widget/home_widget.dart';

import '../../../utils/app_logger.dart';
import 'widget_action.dart';

/// Boundary around the `home_widget` plugin. All plugin-specific concerns live
/// here; the rest of the app deals only in [WidgetAction]s.
class HomeWidgetSource {
  /// Actions from taps while the app is already running (warm launch).
  Stream<WidgetAction> get clicks => HomeWidget.widgetClicked
      .map(widgetActionFromUri)
      .where((action) => action != null)
      .cast<WidgetAction>();

  /// The action the app was cold-launched with, if any.
  ///
  /// The plugin only reports the launch URI once it has attached to the
  /// activity, which can lag a beat behind app start — so we retry briefly
  /// until we get a real action (or give up, meaning this wasn't a widget
  /// launch). Cheap: it runs during the splash while the isolate is otherwise
  /// idle awaiting Firebase.
  Future<WidgetAction?> initialLaunch({
    int retries = 5,
    Duration interval = const Duration(milliseconds: 120),
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        final action = widgetActionFromUri(uri);
        if (action != null) return action;
      } catch (e) {
        AppLogger.warning('HomeWidget initial-launch read failed: $e');
      }
      if (attempt < retries) await Future.delayed(interval);
    }
    return null;
  }
}
