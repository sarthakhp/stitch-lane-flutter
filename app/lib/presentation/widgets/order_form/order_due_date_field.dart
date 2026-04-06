import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/validators/order_validators.dart';

class OrderDueDateField extends FormField<DateTime> {
  OrderDueDateField({
    super.key,
    DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
    bool enabled = true,
    bool isEditing = false,
  }) : super(
          initialValue: selectedDate,
          validator: (value) => OrderValidators.validateDueDate(value, isEdit: isEditing),
          builder: (FormFieldState<DateTime> state) {
            return _DueDateFieldContent(
              selectedDate: state.value,
              errorText: state.errorText,
              enabled: enabled,
              isEditing: isEditing,
              onDateSelected: (date) {
                state.didChange(date);
                onDateSelected(date);
              },
            );
          },
        );
}

class _DueDateFieldContent extends StatelessWidget {
  final DateTime? selectedDate;
  final String? errorText;
  final bool enabled;
  final bool isEditing;
  final ValueChanged<DateTime> onDateSelected;

  const _DueDateFieldContent({
    required this.selectedDate,
    required this.errorText,
    required this.enabled,
    required this.isEditing,
    required this.onDateSelected,
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
          errorText: errorText,
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
