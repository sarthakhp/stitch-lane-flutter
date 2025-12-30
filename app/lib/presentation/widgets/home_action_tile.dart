import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color containerColor;
  final Color contentColor;

  const HomeActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.containerColor,
    required this.contentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: containerColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      ),
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
                  Icon(
                    icon,
                    size: iconSize,
                    color: contentColor,
                  ),
                  const SizedBox(height: AppConfig.spacing8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: constraints.maxWidth > 150 ? null : 14.0,
                      color: contentColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

