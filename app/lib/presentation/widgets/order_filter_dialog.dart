import 'package:flutter/material.dart';
import '../../domain/models/order_filter_options.dart';
import '../../domain/models/filter_preset.dart';
import '../../config/app_config.dart';

class OrderFilterDialog extends StatefulWidget {
  final OrderFilterOptions initialOptions;

  const OrderFilterDialog({
    super.key,
    required this.initialOptions,
  });

  @override
  State<OrderFilterDialog> createState() => _OrderFilterDialogState();
}

class _OrderFilterDialogState extends State<OrderFilterDialog> {
  late OrderFilterOptions _options;
  FilterPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
    _selectedPreset = _findMatchingPreset(_options);
  }

  FilterPreset? _findMatchingPreset(OrderFilterOptions options) {
    for (final preset in FilterPreset.allPresets) {
      if (preset.options == options) {
        return preset;
      }
    }
    return null;
  }

  void _reset() {
    setState(() {
      _options = const OrderFilterOptions();
      _selectedPreset = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(_options);
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      if (_selectedPreset == preset) {
        _options = const OrderFilterOptions();
        _selectedPreset = null;
      } else {
        _options = preset.options;
        _selectedPreset = preset;
      }
    });
  }

  void _updateOption(OrderFilterOptions newOptions) {
    setState(() {
      _options = newOptions;
      _selectedPreset = _findMatchingPreset(newOptions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Filters:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing8),
            Wrap(
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing8,
              children: FilterPreset.allPresets.map((preset) {
                final isSelected = _selectedPreset == preset;
                return FilterChip(
                  avatar: Icon(preset.icon, size: 18),
                  label: Text(preset.name),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: colorScheme.primary,
                  labelStyle: isSelected
                      ? TextStyle(color: colorScheme.onPrimary)
                      : null,
                  onSelected: (_) => _applyPreset(preset),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      CheckboxListTile(
                        title: const Text('Pending'),
                        value: _options.showPending,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          _updateOption(_options.copyWith(showPending: value));
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Ready'),
                        value: _options.showReady,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          _updateOption(_options.copyWith(showReady: value));
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Done'),
                        value: _options.showDone,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          _updateOption(_options.copyWith(showDone: value));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConfig.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppConfig.spacing8),
                      CheckboxListTile(
                        title: const Text('Paid'),
                        value: _options.showPaid,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          _updateOption(_options.copyWith(showPaid: value));
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Not Paid'),
                        value: _options.showNotPaid,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          _updateOption(_options.copyWith(showNotPaid: value));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

