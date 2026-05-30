import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_gateway/usage_event.dart';
import '../../../domain/services/ai_gateway/usage_formatters.dart';

/// Top of the AI usage dashboard — three identical-shape tiles for Today /
/// 7 days / 30 days. INR is the primary currency (single-user app, user in
/// India); USD shown as a secondary line.
class UsageKpiRow extends StatelessWidget {
  final UsageSummary today;
  final UsageSummary week;
  final UsageSummary month;

  const UsageKpiRow({
    super.key,
    required this.today,
    required this.week,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight bounds the Row's height to the tallest tile's intrinsic
    // height. Required because we use [CrossAxisAlignment.stretch] to keep all
    // three tiles the same height — without IntrinsicHeight the Row would try
    // to stretch into the SingleChildScrollView's unbounded vertical space
    // and throw "BoxConstraints forces an infinite height".
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _UsageKpiTile(label: 'Today', summary: today)),
          const SizedBox(width: AppConfig.spacing12),
          Expanded(child: _UsageKpiTile(label: '7 days', summary: week)),
          const SizedBox(width: AppConfig.spacing12),
          Expanded(child: _UsageKpiTile(label: '30 days', summary: month)),
        ],
      ),
    );
  }
}

class _UsageKpiTile extends StatelessWidget {
  final String label;
  final UsageSummary summary;

  const _UsageKpiTile({required this.label, required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              UsageFormatters.inr(summary.totalEstimatedCostUsd),
              style: tt.titleLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              '≈ ${UsageFormatters.usd(summary.totalEstimatedCostUsd)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppConfig.spacing8),
            Row(
              children: [
                Icon(Icons.bolt_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${summary.totalEvents} calls',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
