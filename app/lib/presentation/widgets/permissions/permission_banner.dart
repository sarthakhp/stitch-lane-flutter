import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/permissions/app_permission.dart';
import '../../../domain/services/permissions/permission_prompt_coordinator.dart';
import '../../../domain/state/permission_controller.dart';

/// Top-of-home persistent banner shown whenever any required permission is
/// missing. Self-managing: returns [SizedBox.shrink] when nothing's missing,
/// so the host screen can include it unconditionally.
///
/// On tap, hands off to [PermissionPromptCoordinator] which chooses between
/// the native prompt and a deep-link to system settings.
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PermissionController>();
    if (!controller.initialised || !controller.hasAnyMissing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConfig.spacing12),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppConfig.spacing12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              PermissionPromptCoordinator.runRecoveryFlow(context, controller),
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: colors.onErrorContainer),
                const SizedBox(width: AppConfig.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Some permissions are off',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(controller),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onErrorContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConfig.spacing8),
                Icon(Icons.chevron_right, color: colors.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(PermissionController c) {
    final names = c.missing.map((p) => p.label).join(', ');
    final action = c.anyPermanentlyDenied
        ? 'Tap to open settings.'
        : 'Tap to enable.';
    return '$names — $action';
  }
}
