import 'package:flutter/material.dart';

import 'main_shell_screen.dart';

/// Renders the authenticated home shell.
///
/// The shell (and its bottom bar) is always built so a widget-launched screen
/// can push *inside* the active tab and keep the bottom bar. Cold-start cost is
/// avoided not by skipping the shell build (the dashboard widget is cheap) but
/// by deferring the dashboard's data load while a launched screen covers it —
/// see [MainShellScreen]'s `shellCovered`-gated initial load.
class HomeShellHost extends StatelessWidget {
  const HomeShellHost({super.key});

  @override
  Widget build(BuildContext context) => const MainShellScreen();
}
