import '../../../constants/app_constants.dart';

/// A deep-link action triggered from the Android home-screen widget.
enum WidgetAction { aiChat, createOrder }

extension WidgetActionRouting on WidgetAction {
  /// The named route this action opens.
  String get route {
    switch (this) {
      case WidgetAction.aiChat:
        return AppConstants.aiAssistantRoute;
      case WidgetAction.createOrder:
        return AppConstants.orderCreatorRoute;
    }
  }

  /// Route arguments — both destinations open with the mic auto-listening.
  Map<String, dynamic> get arguments => const {'autoStartVoice': true};
}

/// URI scheme the home-screen widget launches the app with.
const String kWidgetUriScheme = 'stitchgenie';

/// Maps a `stitchgenie://<host>` launch URI to a [WidgetAction], or null for
/// anything we don't recognise.
WidgetAction? widgetActionFromUri(Uri? uri) {
  if (uri == null || uri.scheme != kWidgetUriScheme) return null;
  switch (uri.host) {
    case 'chat':
      return WidgetAction.aiChat;
    case 'order':
      return WidgetAction.createOrder;
    default:
      return null;
  }
}
