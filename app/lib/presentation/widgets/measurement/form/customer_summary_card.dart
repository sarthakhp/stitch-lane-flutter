import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';

/// Read-only "Customer" card shown atop the measurement form.
class CustomerSummaryCard extends StatelessWidget {
  final String name;

  const CustomerSummaryCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
