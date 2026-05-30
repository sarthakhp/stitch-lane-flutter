import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/order_proposal.dart';

/// Inline-editable card for the customer's [ProposedMeasurement]. Body is
/// markdown — we render it as plain multi-line text input; the existing
/// rich-description workflow can be wired in later if needed.
class ProposedMeasurementCard extends StatefulWidget {
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
  State<ProposedMeasurementCard> createState() =>
      _ProposedMeasurementCardState();
}

class _ProposedMeasurementCardState extends State<ProposedMeasurementCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.measurement.description);
  }

  @override
  void didUpdateWidget(covariant ProposedMeasurementCard old) {
    super.didUpdateWidget(old);
    if (_ctrl.text != widget.measurement.description &&
        old.measurement.description != widget.measurement.description) {
      _ctrl.text = widget.measurement.description;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                  onPressed: widget.enabled ? widget.onRemove : null,
                  tooltip: 'Remove measurement',
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            TextField(
              controller: _ctrl,
              enabled: widget.enabled,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Body measurements — markdown allowed.',
                isDense: true,
              ),
              onChanged: widget.onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
