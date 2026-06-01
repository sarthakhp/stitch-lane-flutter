import 'package:flutter/widgets.dart';

import '../../../main.dart' show navigatorKey;
import 'widget_action.dart';

/// Decides when and how a widget launch becomes navigation, and lets the UI
/// defer the (expensive) home dashboard build while a launched destination is
/// on screen.
///
/// Lifecycle:
///   1. [submit] stashes an action (cold launch or a live tap).
///   2. [markShellReady] fires once the app is authenticated.
///   3. When both are present the destination is pushed and [shellCovered]
///      flips true — so the shell host can show a cheap placeholder instead of
///      building the dashboard underneath. It flips back when the user returns.
class WidgetLaunchCoordinator {
  /// True while a widget-launched screen covers the home shell.
  final ValueNotifier<bool> shellCovered = ValueNotifier<bool>(false);

  WidgetAction? _pending;
  bool _shellReady = false;

  bool get hasPending => _pending != null;

  void submit(WidgetAction? action) {
    if (action == null) return;
    _pending = action;
    _tryDispatch();
  }

  void markShellReady() {
    _shellReady = true;
    _tryDispatch();
  }

  void markShellGone() => _shellReady = false;

  void _tryDispatch() {
    if (!_shellReady || _pending == null) return;
    final action = _pending!;
    _pending = null;
    // Cover the shell before it builds so the dashboard is skipped, then push
    // the destination once the frame settles.
    shellCovered.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(action));
  }

  void _navigate(WidgetAction action) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      shellCovered.value = false;
      return;
    }
    navigator
        .pushNamed(action.route, arguments: action.arguments)
        .whenComplete(() => shellCovered.value = false);
  }
}
