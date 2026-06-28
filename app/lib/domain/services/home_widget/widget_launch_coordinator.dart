import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../main.dart' show navigatorKey;
import '../../../screens/shell/shell_tab_navigator_access.dart';
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
    // Mark the shell covered up-front so a cold launch into the creator defers
    // the dashboard's data load (set before the shell first builds). Cleared
    // when the creator is dismissed.
    if (action == WidgetAction.createOrder) shellCovered.value = true;
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
        // Push the creator INSIDE the active tab so the bottom bar stays
        // visible (consistent with in-app navigation). Reset the tab to its
        // root first so it's never stacked on a screen the user had left open.
        // The dashboard load stays deferred (shellCovered) until it's dismissed.
        final tabNav = ShellTabNavigatorAccess.activeNavigator;
        if (tabNav == null) {
          // Shell not mounted yet — fall back to a root push so the action is
          // never dropped.
          navigator.popUntil((route) => route.isFirst);
          navigator
              .pushNamed(action.route, arguments: action.arguments)
              .whenComplete(() => shellCovered.value = false);
          break;
        }
        navigator.popUntil((route) => route.isFirst);
        tabNav.popUntil((route) => route.isFirst);
        tabNav
            .pushNamed(action.route, arguments: action.arguments)
            .whenComplete(() => shellCovered.value = false);
        break;
    }
  }
}
