import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../constants/app_constants.dart';
import '../../main.dart' show navigatorKey;
import '../../utils/app_logger.dart';

/// Which home-screen widget button was tapped.
enum WidgetAction { aiChat, createOrder }

/// Bridges taps on the Android home-screen widget into in-app navigation.
///
/// The native widget launches MainActivity with a `stitchgenie://` URI. We
/// read that URI two ways:
///   - cold start  → [HomeWidget.initiallyLaunchedFromHomeWidget]
///   - warm resume → the [HomeWidget.widgetClicked] stream
///
/// Navigation can only happen once the app is authenticated and the main
/// shell is on screen, so we stash the action and dispatch it when the shell
/// reports ready. Both target screens open with the mic auto-listening.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const String _scheme = 'stitchgenie';

  WidgetAction? _pending;
  bool _shellReady = false;
  StreamSubscription<Uri?>? _clickSub;

  /// Call once from `main()` after the widget binding is ready.
  Future<void> init() async {
    try {
      _clickSub = HomeWidget.widgetClicked.listen(_onUri);
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _onUri(launchUri);
    } catch (e) {
      AppLogger.warning('HomeWidgetService init failed: $e');
    }
  }

  /// Called by the main shell once it is mounted and the app is authenticated.
  void notifyShellReady() {
    _shellReady = true;
    _tryDispatch();
  }

  /// The shell was torn down (e.g. logout) — stop dispatching into a dead tree.
  void notifyShellGone() {
    _shellReady = false;
  }

  void _onUri(Uri? uri) {
    final action = _parse(uri);
    if (action == null) return;
    _pending = action;
    _tryDispatch();
  }

  WidgetAction? _parse(Uri? uri) {
    if (uri == null || uri.scheme != _scheme) return null;
    switch (uri.host) {
      case 'chat':
        return WidgetAction.aiChat;
      case 'order':
        return WidgetAction.createOrder;
      default:
        return null;
    }
  }

  void _tryDispatch() {
    if (!_shellReady || _pending == null) return;
    final action = _pending!;
    _pending = null;
    // Defer to after the current frame so the navigator is settled, whether we
    // arrived here from a cold launch or a live widget tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(action));
  }

  void _navigate(WidgetAction action) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    switch (action) {
      case WidgetAction.aiChat:
        nav.pushNamed(
          AppConstants.aiAssistantRoute,
          arguments: {'autoStartVoice': true},
        );
        break;
      case WidgetAction.createOrder:
        nav.pushNamed(
          AppConstants.orderCreatorRoute,
          arguments: {'autoStartVoice': true},
        );
        break;
    }
  }

  void dispose() {
    _clickSub?.cancel();
    _clickSub = null;
  }
}
