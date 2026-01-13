import 'package:flutter/material.dart';
import '../../domain/models/order_filter_options.dart';
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

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
  }

  void _reset() {
    setState(() {
      _options = const OrderFilterOptions();
    });
  }

  void _apply() {
    Navigator.of(context).pop(_options);
  }

  void _updateOption(OrderFilterOptions newOptions) {
    setState(() {
      _options = newOptions;
    });
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              _buildCheckbox('Pending', _options.showPending, (value) {
                _updateOption(_options.copyWith(showPending: value));
              }),
              _buildCheckbox('Ready', _options.showReady, (value) {
                _updateOption(_options.copyWith(showReady: value));
              }),
              _buildCheckbox('Done', _options.showDone, (value) {
                _updateOption(_options.copyWith(showDone: value));
              }),
              const SizedBox(height: AppConfig.spacing16),
              Text(
                'Payment',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConfig.spacing8),
              _buildCheckbox('Paid', _options.showPaid, (value) {
                _updateOption(_options.copyWith(showPaid: value));
              }),
              _buildCheckbox('Not Paid', _options.showNotPaid, (value) {
                _updateOption(_options.copyWith(showNotPaid: value));
              }),
            ],
          ),
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
