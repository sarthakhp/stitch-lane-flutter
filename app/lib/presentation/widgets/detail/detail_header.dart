import 'package:flutter/material.dart';

import '../../../config/app_config.dart';

/// Generic toolbar for a master–detail "detail" view. Works both as the
/// full-screen top bar (pass a [BackButton] as [leading]) and as the in-pane
/// header on tablet (no leading). Lives inside a Column rather than a Scaffold
/// AppBar so one widget serves both; [SafeArea] clears the status bar.
class DetailHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget> actions;

  const DetailHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        // Min toolbar height, but grows to fit a long name wrapped to 2 lines.
        // The name lives only here now (no duplicate card in the body), so it
        // must stay fully visible.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kToolbarHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null)
                leading!
              else
                const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ...actions,
              const SizedBox(width: AppConfig.spacing8),
            ],
          ),
        ),
      ),
    );
  }
}
