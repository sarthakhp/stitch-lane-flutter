import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_chat_models.dart';

class AiComponentCard extends StatelessWidget {
  final UiComponent component;
  final VoidCallback onTap;

  const AiComponentCard({super.key, required this.component, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Skip if no enriched data
    if (component.title == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCustomer = component.type == 'customer';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppConfig.spacing12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCustomer ? Icons.person : Icons.receipt_long,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const Spacer(),
                Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              component.title!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            for (final detail in component.details)
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
