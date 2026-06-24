import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';

/// Shown once when an old (markdown-only) measurement was imported into a
/// Notes section, so the user knows to review it.
class LegacyImportBanner extends StatelessWidget {
  const LegacyImportBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              'Your earlier note was kept in Notes below — review and move any '
              'measurements into fields if you like.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
