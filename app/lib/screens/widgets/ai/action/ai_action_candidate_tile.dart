import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';
import '../../../../domain/services/ai_action/proposed_action.dart';
import '../../../../presentation/widgets/common/full_image_viewer.dart';
import '../../../../presentation/widgets/common/local_image.dart';

/// One selectable order in the disambiguation list. Shows the customer name,
/// distinguishing lines (phone, title, price, due) and image thumbnails so
/// same-name customers are tellable apart. Tapping selects it; the Open button
/// navigates to the order; a separate Confirm applies the change.
class AiActionCandidateTile extends StatelessWidget {
  final ActionCandidate candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  /// Whether to show the radio dot + selection highlight. False for a
  /// read-only display (e.g. the done card showing what was applied).
  final bool showSelection;

  const AiActionCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
    this.onOpen,
    this.showSelection = true,
  });

  static const double _thumbSize = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(12);
    // Highlight the chosen/applied order whether or not the radio is shown.
    final highlight = selected;

    return Material(
      color: highlight
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.all(AppConfig.spacing12),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: highlight ? colorScheme.primary : colorScheme.outlineVariant,
              width: highlight ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSelection) ...[
                    Icon(
                      selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppConfig.spacing8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        for (final line in candidate.lines)
                          Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Image fills the otherwise-empty right side; tap to enlarge.
                  if (candidate.imagePaths.isNotEmpty) ...[
                    const SizedBox(width: AppConfig.spacing8),
                    _buildSideImage(context),
                  ],
                  if (onOpen != null)
                    IconButton(
                      onPressed: onOpen,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Open order',
                      icon: Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// First image as a tappable thumbnail on the right; tapping opens the
  /// full-screen zoomable gallery. A "+N" badge hints at more images.
  Widget _buildSideImage(BuildContext context) {
    final extra = candidate.imagePaths.length - 1;
    return GestureDetector(
      onTap: () => FullImageViewer.show(
        context,
        imagePaths: candidate.imagePaths,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: _thumbSize,
          height: _thumbSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LocalImage(
                path: candidate.imagePaths.first,
                decodeWidth: _thumbSize,
              ),
              if (extra > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Text(
                      '+$extra',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
