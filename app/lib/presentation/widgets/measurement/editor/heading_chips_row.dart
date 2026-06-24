import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';

/// Horizontal row of "+ Garment" chips (from the user's common headings). Tap
/// one to append a new section with that heading.
class HeadingChipsRow extends StatelessWidget {
  final List<String> headings;
  final bool enabled;
  final ValueChanged<String> onTap;

  const HeadingChipsRow({
    super.key,
    required this.headings,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: headings.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConfig.spacing8),
        itemBuilder: (context, i) {
          final h = headings[i];
          return ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(h),
            onPressed: enabled ? () => onTap(h) : null,
          );
        },
      ),
    );
  }
}

/// Placeholder shown when the measurement has no sections yet.
class EmptyEditorHint extends StatelessWidget {
  final bool hasHeadings;

  const EmptyEditorHint({super.key, required this.hasHeadings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        hasHeadings
            ? 'Tap a garment chip above to start, or use the mic to dictate.'
            : 'Add a garment section, or use the mic to dictate.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
