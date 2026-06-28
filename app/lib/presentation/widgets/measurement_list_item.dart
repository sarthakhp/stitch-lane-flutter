import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/models/measurement.dart';
import '../../config/app_config.dart';
import '../../domain/services/measurement_structurer.dart';
import '../../utils/markdown_helper.dart';
import 'measurement_description_text.dart';
import 'measurement/structured_measurement_view.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBody(context),
              const SizedBox(height: AppConfig.spacing12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, y').format(measurement.modified),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final structured = _tryParseStructured();
    if (structured != null) {
      return StructuredMeasurementView(
        data: structured,
        compact: true,
        maxRows: 5,
      );
    }
    return MeasurementDescriptionText(
      text: MarkdownHelper.getPreviewText(measurement.description, maxLength: 100),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      baseStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }

  StructuredMeasurement? _tryParseStructured() {
    final data = measurement.structuredData;
    if (data == null) return null;
    final s = StructuredMeasurement.fromJson(data);
    return s.isEmpty ? null : s;
  }
}
