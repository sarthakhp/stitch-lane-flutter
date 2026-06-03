import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_chat_models.dart';
import '../../../presentation/widgets/common/local_image.dart';

class AiComponentCard extends StatelessWidget {
  final UiComponent component;
  final VoidCallback onTap;

  const AiComponentCard({super.key, required this.component, required this.onTap});

  static const double _coverHeight = 64;

  @override
  Widget build(BuildContext context) {
    // Skip if no enriched data
    if (component.title == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOrder = component.type == 'order';

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardWidth = 140.0 * textScale;

    final borderRadius = BorderRadius.circular(12);
    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Container(
          width: cardWidth.clamp(120.0, 200.0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order cards get a cover photo (or a subtle placeholder so the
              // row stays even). Customer cards keep the icon header below.
              if (isOrder) _buildCover(context),
              Padding(
                padding: const EdgeInsets.all(AppConfig.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isOrder) ...[
                      Row(
                        children: [
                          Icon(Icons.person, size: 18, color: colorScheme.primary),
                          const Spacer(),
                          Icon(Icons.open_in_new,
                              size: 12, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                    ],
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
            ],
          ),
        ),
      ),
    );
  }

  /// Full-width cover: the order's first photo, or a tinted placeholder when
  /// it has none. The open affordance is overlaid top-right.
  Widget _buildCover(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = component.imagePaths.isNotEmpty;

    return SizedBox(
      height: _coverHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            LocalImage(path: component.imagePaths.first, decodeWidth: 200)
          else
            Container(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Icon(
                Icons.receipt_long,
                size: 24,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.open_in_new, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
