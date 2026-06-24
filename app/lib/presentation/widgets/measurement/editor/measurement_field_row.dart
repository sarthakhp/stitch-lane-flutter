import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';

/// One editable measurement row: a bold label on the left and a compact,
/// centered value box on the right, with a remove button. Stateless — the
/// parent owns the [controller] so focus/cursor survive re-renders.
class MeasurementFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  const MeasurementFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Numbers don't need a full-width field — a compact, filled box keeps
          // the row light and the values vertically aligned.
          SizedBox(
            width: 96,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacing12,
                  vertical: AppConfig.spacing8,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: enabled ? onRemove : null,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
