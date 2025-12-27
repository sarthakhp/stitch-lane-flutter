import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../domain/models/filter_preset.dart';
import 'styled_filter_chip.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: Wrap(
        spacing: AppConfig.spacing8,
        runSpacing: AppConfig.spacing8,
        children: FilterPreset.allPresets.map((preset) {
          return StyledFilterChip(
            icon: preset.icon,
            label: preset.name,
            isSelected: selectedPreset == preset,
            onSelected: () => onPresetSelected(preset),
          );
        }).toList(),
      ),
    );
  }
}

