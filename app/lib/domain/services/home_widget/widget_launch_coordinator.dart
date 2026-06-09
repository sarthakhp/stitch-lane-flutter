import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../main.dart' show navigatorKey;
import '../../state/main_shell_state.dart';
import 'widget_action.dart';

/// Decides when and how a widget launch becomes navigation.
///
/// Lifecycle:
///   1. [submit] stashes an action (cold launch or a live tap).
///   2. [markShellReady] fires once the app is authenticated.
///   3. When both are present the action is dispatched:
///      - "Chat" opens the AI assistant **tab** inside the shell, mic on.
///      - "New order" pushes the full-screen creator and flips [shellCovered]
///        so the host can skip building the dashboard underneath it.
class WidgetLaunchCoordinator {
  /// True while a widget-launched (pushed) screen covers the home shell.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(action));
  }

  void _navigate(WidgetAction action) {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    switch (action) {
      case WidgetAction.aiChat:
        // Open the AI assistant tab in the shell (not a separate screen) with
        // the mic opening. Return to the shell first if something is pushed.
        navigator.popUntil((route) => route.isFirst);
        Provider.of<MainShellState>(context, listen: false)
            .switchToAiTab(startVoice: true);
        break;
      case WidgetAction.createOrder:
        // Return to the root shell first (same as the chat path) so the creator
        // is pushed onto the shell, never stacked on top of some other screen
        // the user had left open. Then cover the dashboard while it's open.
        navigator.popUntil((route) => route.isFirst);
        shellCovered.value = true;
        navigator
            .pushNamed(action.route, arguments: action.arguments)
            .whenComplete(() => shellCovered.value = false);
        break;
    }
  }
}
