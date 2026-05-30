import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/models/analytics.dart';
import 'kpi_card.dart';

/// Headline metrics block. Numeric tiles (total/count/average/highest) live
/// in a 2-column grid; insight tiles whose values may be long strings (top
/// customer, future: top order, busiest day, etc.) get a full-width row
/// underneath so the grid never has to size itself around variable text.
class KpiGrid extends StatelessWidget {
  final RangeKpis kpis;

  const KpiGrid({super.key, required this.kpis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppConfig.spacing12,
          mainAxisSpacing: AppConfig.spacing12,
          childAspectRatio: 1.6,
          children: [
            KpiCard(
              label: 'Total paid',
              value: '₹${kpis.totalPaid}',
              icon: Icons.payments_outlined,
            ),
            KpiCard(
              label: 'Payments',
              value: '${kpis.paymentCount}',
              icon: Icons.receipt_long_outlined,
            ),
            KpiCard(
              label: 'Average',
              value: '₹${kpis.averagePayment}',
              icon: Icons.trending_flat_outlined,
            ),
            KpiCard(
              label: 'Highest',
              value: '₹${kpis.highestPayment}',
              icon: Icons.trending_up_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppConfig.spacing12),
        _TopCustomerCard(
          name: kpis.topCustomerName,
          amount: kpis.topCustomerAmount,
        ),
      ],
    );
  }
}

class _TopCustomerCard extends StatelessWidget {
  final String? name;
  final int amount;

  const _TopCustomerCard({required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasCustomer = name != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Row(
          children: [
            Icon(Icons.star_outline, color: colorScheme.primary),
            const SizedBox(width: AppConfig.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Top customer',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing4),
                  Text(
                    hasCustomer ? name! : '—',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConfig.spacing12),
            if (hasCustomer)
              Text(
                '₹$amount',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
