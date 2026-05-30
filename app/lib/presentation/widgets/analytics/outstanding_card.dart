import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/models/analytics.dart';

/// "Money still owed" headline card — complements the paid-totals view so
/// users see both sides of the books from the analysis screen.
class OutstandingCard extends StatelessWidget {
  final OutstandingSummary summary;
  final VoidCallback? onTap;

  const OutstandingCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasOutstanding = summary.totalUnpaid > 0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 32,
                color: hasOutstanding ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacing4),
                    Text(
                      '₹${summary.totalUnpaid}',
                      style: textTheme.headlineSmall?.copyWith(
                        color: hasOutstanding
                            ? colorScheme.error
                            : colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacing4),
                    Text(
                      summary.openOrderCount == 1
                          ? 'across 1 open order'
                          : 'across ${summary.openOrderCount} open orders',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
}
