import 'package:flutter/material.dart';

import '../domain/services/home_widget/home_widget_service.dart';
import 'main_shell_screen.dart';
import 'widgets/app_logo.dart';

/// Renders the authenticated home.
///
/// On a cold widget launch the shell is "covered" before the first build, so
/// we show a lightweight splash instead of building the (expensive) dashboard
/// underneath a destination the user launched straight into. Once the
/// dashboard has been built it stays built — warm widget taps never tear it
/// down, so returning from a widget destination is instant.
class HomeShellHost extends StatefulWidget {
  const HomeShellHost({super.key});

  @override
  State<HomeShellHost> createState() => _HomeShellHostState();
}

class _HomeShellHostState extends State<HomeShellHost> {
  bool _shellBuilt = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: HomeWidgetService.instance.shellCovered,
      builder: (context, covered, _) {
        if (covered && !_shellBuilt) {
          return const Scaffold(body: Center(child: AppLogo(size: 120)));
        }
        _shellBuilt = true;
        return const MainShellScreen();
      },
    );
  }
}
