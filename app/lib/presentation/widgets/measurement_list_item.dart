import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/models/measurement.dart';
import '../../config/app_config.dart';

class MeasurementListItem extends StatelessWidget {
  final Measurement measurement;
  final VoidCallback onTap;

  const MeasurementListItem({
    super.key,
    required this.measurement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing12,
        ),
        title: Text(
          _getPreviewText(),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'Created: ${DateFormat('MMM d, y').format(measurement.created)}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              'Modified: ${DateFormat('MMM d, y').format(measurement.modified)}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _getPreviewText() {
    if (measurement.description.length <= 100) {
      return measurement.description;
    }
    return '${measurement.description.substring(0, 100)}...';
  }
}

