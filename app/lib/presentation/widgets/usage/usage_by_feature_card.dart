import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/ai_gateway/usage_event.dart';
import '../../../domain/services/ai_gateway/usage_formatters.dart';

/// Breakdown of spend across features for the selected time window.
///
/// One row per `caller_tag`. Each row shows: icon, humanized label, event
/// count, cost (INR), and a proportional horizontal bar so the user can see
/// at a glance which feature is the budget hog. Sorted by cost descending so
/// the loudest spend lives at the top.
class UsageByFeatureCard extends StatelessWidget {
  final Map<String, UsageSummary> byFeature;

  const UsageByFeatureCard({super.key, required this.byFeature});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final entries = byFeature.entries.toList()
      ..sort((a, b) => b.value.totalEstimatedCostUsd
          .compareTo(a.value.totalEstimatedCostUsd));

    final maxCost = entries.isEmpty
        ? 0.0
        : entries.first.value.totalEstimatedCostUsd;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.donut_small_outlined, size: 18, color: cs.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text(
                  'By feature',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppConfig.spacing16),
                child: Text(
                  'No calls in this window yet.',
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              for (var i = 0; i < entries.length; i++) ...[
                _FeatureRow(
                  tag: entries[i].key,
                  summary: entries[i].value,
                  // Avoid divide-by-zero, avoid wildly tiny bars: fall back to
                  // a 0-share rendering if there's no spend at all yet.
                  share: maxCost > 0
                      ? entries[i].value.totalEstimatedCostUsd / maxCost
                      : 0,
                ),
                if (i < entries.length - 1)
                  const SizedBox(height: AppConfig.spacing12),
              ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String tag;
  final UsageSummary summary;
  final double share;

  const _FeatureRow({
    required this.tag,
    required this.summary,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = UsageFormatters.callerColor(tag, cs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(UsageFormatters.callerIcon(tag),
                  size: 16, color: accent),
            ),
            const SizedBox(width: AppConfig.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    UsageFormatters.callerLabel(tag),
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    () {
                      final provider = UsageFormatters.callerProvider(tag);
                      final calls = '${summary.totalEvents} calls';
                      return provider == null
                          ? calls
                          : '$calls · via $provider';
                    }(),
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConfig.spacing12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  UsageFormatters.inr(summary.totalEstimatedCostUsd),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  UsageFormatters.usd(summary.totalEstimatedCostUsd),
                  style:
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppConfig.spacing8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
    );
  }
}
