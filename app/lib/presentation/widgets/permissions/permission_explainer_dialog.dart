import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/permissions/app_permission.dart';
import 'permission_icon.dart';

/// First-run "soft prompt" — explains *why* the app wants each permission
/// before Android's blunt system dialogs appear. Returns `true` when the
/// user taps Allow, `false` (or null) when they tap Not now / dismiss.
///
/// Visually mirrors the home-tab vocabulary (rounded card surface, per-row
/// container colours) so it reads as part of StitchGenie, not a system alert.
class PermissionExplainerDialog extends StatelessWidget {
  const PermissionExplainerDialog({super.key});

  /// Show as a modal and return the user's choice. `true` means "go ahead
  /// and request"; everything else means "not now".
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PermissionExplainerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing24,
        vertical: AppConfig.spacing24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppConfig.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            SizedBox(height: AppConfig.spacing16),
            _PermissionList(),
            SizedBox(height: AppConfig.spacing16),
            _Footnote(),
            SizedBox(height: AppConfig.spacing16),
            _Actions(),
          ],
        ),
      ),
    );
  }
}

/// Friendly hero — waving hand mirrors [WelcomeHero] on the home tab so the
/// dialog feels like an extension of the app, not a system interruption.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppConfig.spacing12),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.waving_hand,
            color: colors.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: AppConfig.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's get you set up",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'A couple of quick permissions and you’re ready.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Iterates the permission list, pairing each row with a distinct
/// container colour from the Material 3 scheme — matches the per-card
/// colouring used on the home tab's KPI/action cards.
class _PermissionList extends StatelessWidget {
  const _PermissionList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme);
    const perms = AppPermission.values;
    return Column(
      children: [
        for (int i = 0; i < perms.length; i++) ...[
          if (i > 0) const SizedBox(height: AppConfig.spacing12),
          _PermissionTile(
            permission: perms[i],
            containerColor: palette[i % palette.length].$1,
            contentColor: palette[i % palette.length].$2,
          ),
        ],
      ],
    );
  }

  /// (container, on-container) colour pairs that match the home-tab cards.
  static List<(Color, Color)> _palette(ThemeData theme) {
    final c = theme.colorScheme;
    return [
      (c.primaryContainer, c.onPrimaryContainer),
      (c.tertiaryContainer, c.onTertiaryContainer),
      (c.secondaryContainer, c.onSecondaryContainer),
    ];
  }
}

class _PermissionTile extends StatelessWidget {
  final AppPermission permission;
  final Color containerColor;
  final Color contentColor;

  const _PermissionTile({
    required this.permission,
    required this.containerColor,
    required this.contentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing12,
      ),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(AppConfig.spacing16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PermissionIcon(
            permission: permission,
            color: contentColor,
            size: 22,
          ),
          const SizedBox(width: AppConfig.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: contentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  permission.rationale,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: contentColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      "You can change any of these later in your phone's settings.",
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        const SizedBox(width: AppConfig.spacing8),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacing24,
              vertical: AppConfig.spacing12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.spacing16),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
