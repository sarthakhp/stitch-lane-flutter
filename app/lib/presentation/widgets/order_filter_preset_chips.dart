import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../domain/models/filter_preset.dart';

class OrderFilterPresetChips extends StatelessWidget {
  final FilterPreset? selectedPreset;
  final ValueChanged<FilterPreset> onPresetSelected;

  const OrderFilterPresetChips({
    super.key,
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: FilterPreset.allPresets.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppConfig.spacing8),
        itemBuilder: (context, index) {
          final preset = FilterPreset.allPresets[index];
          final isSelected = selectedPreset == preset;
          final colorScheme = Theme.of(context).colorScheme;

          return FilterChip(
            avatar: Icon(preset.icon, size: 18),
            label: Text(preset.name),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: colorScheme.primary,
            labelStyle: isSelected
                ? TextStyle(color: colorScheme.onPrimary)
                : null,
            onSelected: (_) => onPresetSelected(preset),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

