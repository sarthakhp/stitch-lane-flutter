import 'dart:async';

import 'package:flutter/foundation.dart';

import 'home_widget_source.dart';
import 'widget_action.dart';
import 'widget_launch_coordinator.dart';

/// App-facing facade for the home-screen widget feature. Wires the plugin
/// [HomeWidgetSource] to the [WidgetLaunchCoordinator] and exposes a small,
/// stable API to the app shell.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  final HomeWidgetSource _source = HomeWidgetSource();
  final WidgetLaunchCoordinator _coordinator = WidgetLaunchCoordinator();

  StreamSubscription<WidgetAction>? _clickSub;
  bool _initialCaptured = false;

  /// Whether a widget-launched destination is currently covering the home
  /// shell. The shell host watches this to defer the dashboard build.
  ValueListenable<bool> get shellCovered => _coordinator.shellCovered;

  /// Subscribe to live (warm) widget taps. Call once from `main()`.
  void init() {
    _clickSub = _source.clicks.listen(_coordinator.submit);
  }

  /// Read the cold-start launch action. Call once early (when the root boots)
  /// so it resolves during the splash, before the shell would build.
  Future<void> captureInitialLaunch() async {
    if (_initialCaptured) return;
    _initialCaptured = true;
    _coordinator.submit(await _source.initialLaunch());
  }

  /// The authenticated shell is on screen — safe to dispatch a pending launch.
  void markShellReady() => _coordinator.markShellReady();

  /// The authenticated shell went away (e.g. logout).
  void markShellGone() => _coordinator.markShellGone();

  void dispose() {
    _clickSub?.cancel();
    _clickSub = null;
  }
}
