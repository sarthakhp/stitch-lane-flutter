import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/models/analytics.dart';

/// One tappable row in the months list. Shows the month label, total paid,
/// and payment count; tap to drill into the month detail screen.
class MonthTile extends StatelessWidget {
  final String label;
  final MonthSummary summary;
  final VoidCallback onTap;

  const MonthTile({
    super.key,
    required this.label,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.titleMedium),
                  const SizedBox(height: AppConfig.spacing4),
                  Text(
                    '₹${summary.totalPaid}',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing4),
                  Text(
                    summary.paymentCount == 1
                        ? '1 payment'
                        : '${summary.paymentCount} payments',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
