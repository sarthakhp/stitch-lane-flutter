import 'package:flutter/material.dart';

/// Generic, content-agnostic master–detail scaffold.
///
/// Two panes side by side on a **tablet in landscape** — a fixed-width [master]
/// and a flexible [detail]; a single full-width column otherwise (phones, and
/// tablets in portrait), where the host navigates to detail.
///
/// Keying off "tablet + landscape" (not a raw pixel width) makes rotation
/// predictable — portrait is always the list, landscape always two panes — and
/// keeps phones single-column regardless of orientation.
///
/// Knows nothing about what it's listing — reuse for orders, customers, etc.
class MasterDetailLayout extends StatelessWidget {
  final Widget master;

  /// The selected item's detail pane, or null when nothing is selected
  /// (then [placeholder] is shown). Only used in two-pane mode.
  final Widget? detail;

  /// Shown in the detail pane when [detail] is null.
  final Widget placeholder;

  /// Fixed width of the master pane in two-pane mode.
  final double masterPaneWidth;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    required this.placeholder,
    this.masterPaneWidth = 440,
  });

  /// Whether the host should treat taps as in-pane selection (true) vs. a
  /// navigation push (false). True only on a tablet held in landscape.
  static bool isTwoPane(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final isLandscape = size.width >= size.height;
    return isTablet && isLandscape;
  }

  @override
  Widget build(BuildContext context) {
    // Single column fills the width (portrait / phone). Landscape tablets go
    // two-pane, so a too-wide single column never occurs and needs no cap.
    if (!isTwoPane(context)) return master;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: masterPaneWidth, child: master),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: detail ?? placeholder),
      ],
    );
  }
}

/// Empty-state shown in the detail pane when nothing is selected.
class MasterDetailPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;

  const MasterDetailPlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
