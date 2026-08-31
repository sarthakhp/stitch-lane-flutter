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
      if (shown.isNotEmpty) {
        inner.add(_MeasurementGrid(entries: shown, compact: compact));
      }
      if (!compact && notes.isNotEmpty) {
        inner.add(const SizedBox(height: AppConfig.spacing8));
        inner.add(_Notes(text: notes));
      }

      blocks.add(_GarmentBlock(compact: compact, children: inner));
    }

    final body = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        body.add(SizedBox(
            height: compact ? AppConfig.spacing8 : AppConfig.spacing12));
      }
      body.add(blocks[i]);
    }
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body);

    // Nothing truncated → show the content as-is (e.g. the full detail view).
    if (hidden <= 0) return content;

    // Truncated preview: fade the bottom edge so it reads at a glance as "there
    // is more below", and still label exactly how many rows are hidden.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BottomFade(child: content),
        SizedBox(height: compact ? AppConfig.spacing8 : AppConfig.spacing12),
        Text(
          '+$hidden more',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Fades [child] toward transparent along its bottom edge, so a truncated
/// preview visually signals that the list continues. The top ~70% stays fully
/// opaque; only the last rows dissolve.
class _BottomFade extends StatelessWidget {
  final Widget child;

  const _BottomFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect),
      child: child,
    );
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

/// Lays out a garment's `label: value` rows in a grid, switching from one
/// column to two once there's enough width (tablet/landscape) — otherwise a
/// single wide row leaves the label pinned left and the value pinned far
/// right, with a large empty gap between them. Divider lines between rows
/// (and between columns) make each label easy to trace across to its value.
class _MeasurementGrid extends StatelessWidget {
  final List<MapEntry<String, String>> entries;
  final bool compact;

  const _MeasurementGrid({required this.entries, required this.compact});

  static const double _twoColumnBreakpoint = 480;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            !compact && constraints.maxWidth >= _twoColumnBreakpoint ? 2 : 1;

        final rows = <Widget>[];
        for (var i = 0; i < entries.length; i += columns) {
          if (rows.isNotEmpty) {
            rows.add(Divider(
              height: compact ? 9 : 13,
              thickness: 1,
              color: dividerColor,
            ));
          }

          final rowItems = <Widget>[];
          for (var col = 0; col < columns; col++) {
            final index = i + col;
            if (col > 0 && index < entries.length) {
              rowItems.add(VerticalDivider(
                width: AppConfig.spacing16,
                thickness: 1,
                color: dividerColor,
              ));
            }
            rowItems.add(Expanded(
              child: index < entries.length
                  ? _MeasurementRow(
                      label: entries[index].key,
                      value: entries[index].value,
                      compact: compact,
                    )
                  : const SizedBox.shrink(),
            ));
          }
          // IntrinsicHeight gives the VerticalDivider a real height to draw
          // against — inside a plain Row it has no bound and renders as
          // nothing.
          rows.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems),
          ));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
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
