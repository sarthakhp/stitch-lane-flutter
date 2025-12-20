import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isCreateAction;

  const HomeActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.isCreateAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ??
        (isCreateAction ? theme.colorScheme.primary : theme.colorScheme.onPrimary);
    final effectiveBackgroundColor = backgroundColor ??
        (isCreateAction ? null : theme.colorScheme.primary);

    return Card(
      color: effectiveBackgroundColor,
      elevation: isCreateAction ? 1 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconSize = constraints.maxWidth > 150 ? 40.0 : 32.0;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: effectiveIconColor,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: constraints.maxWidth > 150 ? null : 14.0,
                        color: isCreateAction ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onPrimary,
                        fontWeight: isCreateAction ? null : FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Flexible(
                    flex: 2,
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isCreateAction
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onPrimary,
                        fontSize: constraints.maxWidth > 150 ? null : 11.0,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

