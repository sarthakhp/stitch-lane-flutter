import 'package:flutter/material.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import 'customer_picker.dart';

/// Navigates to create a new customer (prefilled with [prefillName]) and
/// resolves to the created customer, or null if cancelled. Injected by the
/// screen so this widget layer never imports screen code.
typedef CreateCustomerCallback = Future<Customer?> Function(String? prefillName);

/// Opens [CustomerPicker] in a modal bottom sheet and resolves to the chosen
/// (or newly created) customer, or null if dismissed.
class CustomerPickerSheet {
  static Future<Customer?> show(
    BuildContext context, {
    required List<Customer> customers,
    required CreateCustomerCallback onCreateNew,
  }) {
    return showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _CustomerPickerSheetBody(
          customers: customers,
          onCreateNew: onCreateNew,
        );
      },
    );
  }
}

class _CustomerPickerSheetBody extends StatelessWidget {
  final List<Customer> customers;
  final CreateCustomerCallback onCreateNew;

  const _CustomerPickerSheetBody({
    required this.customers,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: AppConfig.spacing12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConfig.spacing16),
              child: Row(
                children: [
                  Text(
                    'Select customer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacing16,
                ),
                child: CustomerPicker(
                  customers: customers,
                  onSelected: (c) => Navigator.of(context).pop(c),
                  onCreateNew: (prefill) async {
                    final created = await onCreateNew(prefill);
                    if (created != null && context.mounted) {
                      Navigator.of(context).pop(created);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form field that shows the selected customer and opens [CustomerPickerSheet]
/// on tap. Validates that a customer is selected. Drop-in replacement for the
/// old autocomplete field in forms.
class CustomerPickerField extends FormField<Customer> {
  CustomerPickerField({
    super.key,
    required List<Customer> customers,
    Customer? selectedCustomer,
    required ValueChanged<Customer?> onChanged,
    required CreateCustomerCallback onCreateNew,
    bool enabled = true,
  }) : super(
          initialValue: selectedCustomer,
          validator: (value) =>
              value == null ? 'Please select a customer' : null,
          builder: (state) {
            return _CustomerPickerFieldContent(
              customers: customers,
              selected: state.value,
              errorText: state.errorText,
              enabled: enabled,
              onPicked: (customer) {
                state.didChange(customer);
                onChanged(customer);
              },
              onCleared: () {
                state.didChange(null);
                onChanged(null);
              },
              onCreateNew: onCreateNew,
            );
          },
        );
}

class _CustomerPickerFieldContent extends StatelessWidget {
  final List<Customer> customers;
  final Customer? selected;
  final String? errorText;
  final bool enabled;
  final ValueChanged<Customer> onPicked;
  final VoidCallback onCleared;
  final CreateCustomerCallback onCreateNew;

  const _CustomerPickerFieldContent({
    required this.customers,
    required this.selected,
    required this.errorText,
    required this.enabled,
    required this.onPicked,
    required this.onCleared,
    required this.onCreateNew,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await CustomerPickerSheet.show(
      context,
      customers: customers,
      onCreateNew: onCreateNew,
    );
    if (result != null) onPicked(result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = selected != null;

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Customer',
          prefixIcon: const Icon(Icons.person),
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: hasSelection && enabled
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onCleared,
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        isEmpty: !hasSelection,
        child: hasSelection
            ? Text(
                selected!.name,
                style: Theme.of(context).textTheme.bodyLarge,
              )
            : Text(
                'Select customer',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
