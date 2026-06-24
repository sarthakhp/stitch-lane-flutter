import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/measurement_structurer.dart';

/// Read-only renderer for a [StructuredMeasurement], matching the edit screen's
/// layout so a measurement looks the same everywhere it's shown: each garment
/// is a titled section (accent bar + bold heading), and each measurement is a
/// `Label …… value` row — bold label on the left, value in a soft box on the
/// right. This is the layout the user scans fastest ("what's the length?").
///
/// [compact] tightens everything for list/summary cards. [maxRows] caps the
/// number of measurement rows shown (across all sections) and appends a
/// "+N more" line — used by the preview card so its height stays bounded.
class StructuredMeasurementView extends StatelessWidget {
  final StructuredMeasurement data;
  final bool compact;
  final int? maxRows;

  const StructuredMeasurementView({
    super.key,
    required this.data,
    this.compact = false,
    this.maxRows,
  });

  @override
  Widget build(BuildContext context) {
    var budget = maxRows ?? 1 << 30;
    var hidden = 0;
    final blocks = <Widget>[];

    for (final section in data.sections) {
      final entries = section.values.entries
          .where((e) => e.value.trim().isNotEmpty)
          .toList();
      final notes = section.notes.trim();
      final hasHeading = section.heading.trim().isNotEmpty;
      if (entries.isEmpty && notes.isEmpty && !hasHeading) continue;

      // Out of row budget (preview cap): tally the rest, render nothing more.
      if (budget <= 0) {
        hidden += entries.length;
        continue;
      }

      final shown = entries.take(budget).toList();
      hidden += entries.length - shown.length;
      budget -= shown.length;

      // Build this garment's content, then wrap it as its own block so
      // garments are visually separated.
      final inner = <Widget>[];
      if (hasHeading) {
        inner.add(_SectionHeading(title: section.heading.trim(), compact: compact));
        inner.add(SizedBox(
            height: compact ? AppConfig.spacing8 : AppConfig.spacing12));
      }
      for (final e in shown) {
        inner.add(_MeasurementRow(label: e.key, value: e.value, compact: compact));
      }
      if (!compact && notes.isNotEmpty) {
        inner.add(const SizedBox(height: AppConfig.spacing8));
        inner.add(_Notes(text: notes));
      }

      blocks.add(_GarmentBlock(compact: compact, children: inner));
    }

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        children.add(SizedBox(
            height: compact ? AppConfig.spacing8 : AppConfig.spacing12));
      }
      children.add(blocks[i]);
    }

    if (hidden > 0) {
      children.add(SizedBox(height: compact ? AppConfig.spacing8 : AppConfig.spacing12));
      children.add(Text(
        '+$hidden more',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// One garment rendered as a bordered block, so adjacent garments read as
/// clearly separate cards rather than one long list.
class _GarmentBlock extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const _GarmentBlock({required this.compact, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? AppConfig.spacing12 : AppConfig.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final bool compact;

  const _SectionHeading({required this.title, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: compact ? 16 : 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppConfig.spacing8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _MeasurementRow({
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : AppConfig.spacing4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppConfig.spacing8),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 56 : 84),
            padding: EdgeInsets.symmetric(
              horizontal: AppConfig.spacing12,
              vertical: compact ? 4 : AppConfig.spacing8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  final String text;
  const _Notes({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
