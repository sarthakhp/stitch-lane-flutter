import 'package:flutter/material.dart';

class StyledFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const StyledFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? colorScheme.onPrimary : null,
      ),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: colorScheme.primary,
      labelStyle: isSelected ? TextStyle(color: colorScheme.onPrimary) : null,
      onSelected: (_) => onSelected(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

