import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/models/measurement.dart';
import '../../config/app_config.dart';

class MeasurementCard extends StatelessWidget {
  final Measurement? latestMeasurement;
  final VoidCallback onCreateNew;
  final VoidCallback onViewAll;
  final VoidCallback? onTapLatest;

  const MeasurementCard({
    super.key,
    this.latestMeasurement,
    required this.onCreateNew,
    required this.onViewAll,
    this.onTapLatest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.straighten,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppConfig.spacing16),
                Expanded(
                  child: Text(
                    'Measurements',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (latestMeasurement != null) ...[
              const SizedBox(height: AppConfig.spacing16),
              InkWell(
                onTap: onTapLatest,
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                child: Container(
                  padding: const EdgeInsets.all(AppConfig.spacing12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Latest Measurement',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (onTapLatest != null)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      Text(
                        _getPreviewText(latestMeasurement!.description),
                        style: textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppConfig.spacing12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Created: ${DateFormat('MMM d, y').format(latestMeasurement!.created)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConfig.spacing4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Modified: ${DateFormat('MMM d, y').format(latestMeasurement!.modified)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: AppConfig.spacing12),
              Text(
                'No measurements yet',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppConfig.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCreateNew,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New'),
                  ),
                ),
                const SizedBox(width: AppConfig.spacing12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.list),
                    label: const Text('View All'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewText(String description) {
    if (description.length <= 150) {
      return description;
    }
    return '${description.substring(0, 150)}...';
  }
}

