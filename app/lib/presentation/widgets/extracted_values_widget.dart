import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../domain/services/money_extractor.dart';

class ExtractedValuesWidget extends StatelessWidget {
  final List<double> values;
  final VoidCallback onApply;

  const ExtractedValuesWidget({
    super.key,
    required this.values,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              MoneyExtractor.formatTotal(values),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppConfig.spacing8),
          FilledButton.tonal(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacing12,
                vertical: AppConfig.spacing4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

