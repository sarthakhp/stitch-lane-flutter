import 'package:flutter/widgets.dart';

/// App-wide responsive size buckets. Drives layout decisions on phones vs
/// tablets so screens can be built once and adapt. Reuse this everywhere
/// instead of hand-rolling width checks.
enum WindowSize { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();

  /// >= this width is a small tablet / large foldable (e.g. portrait tablet).
  static const double medium = 600;

  /// >= this width is a full tablet in landscape / desktop.
  static const double expanded = 1000;

  /// Max comfortable content width — content beyond this is centered so cards
  /// don't stretch into unreadable bars on very wide screens.
  static const double maxContentWidth = 1400;

  static WindowSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => Breakpoints.of(this);

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// Anything bigger than a phone.
  bool get isTablet => windowSize != WindowSize.compact;

  /// Pick a value per window size, falling back to smaller buckets when a
  /// larger one isn't supplied. `compact` is always required.
  T responsive<T>({required T compact, T? medium, T? expanded}) {
    switch (windowSize) {
      case WindowSize.expanded:
        return expanded ?? medium ?? compact;
      case WindowSize.medium:
        return medium ?? compact;
      case WindowSize.compact:
        return compact;
    }
  }
}
