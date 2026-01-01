import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderDueDateField extends StatelessWidget {
  final DateTime? selectedDate;
  final bool enabled;
  final bool showError;
  final bool isEditing;
  final ValueChanged<DateTime> onDateSelected;

  const OrderDueDateField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.enabled = true,
    this.showError = false,
    this.isEditing = false,
  });

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = selectedDate ?? now;
    final firstDate = isEditing ? DateTime(2000) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? () => _selectDate(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Due Date',
          hintText: 'Select due date',
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
          errorText: showError ? 'Due date is required' : null,
        ),
        child: Text(
          selectedDate != null
              ? _formatDate(selectedDate!)
              : 'Tap to select date',
          style: selectedDate != null
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
        ),
      ),
    );
  }
}

