import 'package:flutter/material.dart';
import '../../domain/domain.dart';

class CustomerSortDropdown extends StatelessWidget {
  final CustomerSort selectedSort;
  final ValueChanged<CustomerSort> onSortChanged;

  const CustomerSortDropdown({
    super.key,
    required this.selectedSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CustomerSort>(
                value: selectedSort,
                isExpanded: true,
                items: CustomerSort.values.map((sort) {
                  return DropdownMenuItem(
                    value: sort,
                    child: Text(sort.displayName),
                  );
                }).toList(),
                onChanged: (CustomerSort? value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

