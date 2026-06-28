import 'package:flutter/widgets.dart';

/// Bridges code outside the widget tree (e.g. the home-widget deep-link
/// coordinator) to the shell's *active tab* [Navigator], so a deep-linked
/// screen pushes inside the current tab — keeping the bottom bar — instead of
/// covering the whole shell via the root navigator.
///
/// [MainShellScreen] registers a resolver while mounted and clears it on
/// dispose. Callers must tolerate a null result (shell not built yet) and fall
/// back to the root navigator.
class ShellTabNavigatorAccess {
  ShellTabNavigatorAccess._();

  static NavigatorState? Function()? _resolver;

  static void register(NavigatorState? Function() resolver) =>
      _resolver = resolver;

  static void clear(NavigatorState? Function() resolver) {
    if (identical(_resolver, resolver)) _resolver = null;
  }

  /// The currently-visible tab's navigator, or null if the shell isn't mounted.
  static NavigatorState? get activeNavigator => _resolver?.call();
}
