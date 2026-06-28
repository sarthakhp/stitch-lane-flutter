import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../screens/widgets/app_logo.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final bool showLogo;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final boldTitle = DefaultTextStyle.merge(
      style: const TextStyle(fontWeight: FontWeight.bold),
      child: title,
    );

    Widget titleWidget = boldTitle;
    if (showLogo) {
      titleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 32, showText: false),
          const SizedBox(width: AppConfig.spacing8),
          Flexible(child: boldTitle),
        ],
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      title: titleWidget,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      // Stay flat white on scroll. Pinning backgroundColor + transparent tint +
      // zero scrolled-under elevation stops Material 3 from greying the bar when
      // a list scrolls beneath it (the global theme can't pin the colour for the
      // scrolledUnder state, so we do it here on the one shared app bar).
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      actions: actions != null
          ? [
              Padding(
                padding: const EdgeInsets.only(
                  right: AppConfig.spacing8,
                  top: AppConfig.spacing8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ),
            ]
          : null,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize {
    final double bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}

