import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/order_proposal.dart';
import 'editable_markdown_field.dart';

/// Inline-editable card for the customer's [ProposedMeasurement]. The body is
/// markdown — shown rendered (real headings/bold/bullets) with a pencil to
/// edit, via [EditableMarkdownField], so the draft matches the saved record.
class ProposedMeasurementCard extends StatelessWidget {
  final ProposedMeasurement measurement;
  final bool enabled;
  final ValueChanged<String> onEdit;
  final VoidCallback onRemove;

  const ProposedMeasurementCard({
    super.key,
    required this.measurement,
    required this.enabled,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text(
                    'Measurements',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  onPressed: enabled ? onRemove : null,
                  tooltip: 'Remove measurement',
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            EditableMarkdownField(
              value: measurement.description,
              enabled: enabled,
              hintText: 'Body measurements — markdown allowed.',
              minLines: 4,
              maxLines: 10,
              onChanged: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
