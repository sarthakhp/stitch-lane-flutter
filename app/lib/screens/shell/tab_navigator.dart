import 'package:flutter/material.dart';

import '../../config/routes.dart';

/// A per-tab [Navigator] so detail screens push *within* a tab and the shell's
/// bottom bar stays visible. The tab's first screen is built by [rootBuilder];
/// every other route delegates to the app's shared [AppRoutes.generateRoute],
/// so existing `Navigator.pushNamed` calls inside a tab just work — they resolve
/// to this nested navigator instead of the root one.
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootBuilder,
    this.observers = const [],
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder rootBuilder;
  final List<NavigatorObserver> observers;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: observers,
      onGenerateRoute: (settings) {
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute(builder: rootBuilder, settings: settings);
        }
        return AppRoutes.generateRoute(settings);
      },
    );
  }
}
