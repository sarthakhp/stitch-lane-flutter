import 'package:flutter/material.dart';
import '../../backend/models/customer.dart';

class CustomerAutocompleteField extends StatelessWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onCustomerSelected;
  final VoidCallback onCustomerCleared;
  final VoidCallback onCreateNewCustomer;
  final bool enabled;
  final bool hasError;

  const CustomerAutocompleteField({
    super.key,
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerSelected,
    required this.onCustomerCleared,
    required this.onCreateNewCustomer,
    this.enabled = true,
    this.hasError = false,
  });

  List<Customer> _getSortedCustomers() {
    return List<Customer>.from(customers)
      ..sort((a, b) => b.created.compareTo(a.created));
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Customer>(
      initialValue: selectedCustomer != null
          ? TextEditingValue(text: selectedCustomer!.name)
          : const TextEditingValue(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final searchText = textEditingValue.text.trim();
        final sortedCustomers = _getSortedCustomers();

        if (searchText.isEmpty) {
          return sortedCustomers;
        }
        final searchLower = searchText.toLowerCase();
        return sortedCustomers.where((Customer customer) {
          return customer.name.toLowerCase().contains(searchLower) ||
              (customer.phoneNumber?.contains(searchText) ?? false);
        });
      },
      displayStringForOption: (Customer customer) => customer.name,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return _CustomerTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          hasError: hasError,
          selectedCustomer: selectedCustomer,
          onFieldSubmitted: onFieldSubmitted,
          onClear: () {
            onCustomerCleared();
            controller.clear();
            focusNode.requestFocus();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _CustomerOptionsView(
          options: options,
          onSelected: onSelected,
          onCreateNew: onCreateNewCustomer,
        );
      },
      onSelected: (Customer customer) {
        onCustomerSelected(customer);
        FocusScope.of(context).unfocus();
      },
    );
  }
}

class _CustomerTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final Customer? selectedCustomer;
  final VoidCallback onFieldSubmitted;
  final VoidCallback onClear;

  const _CustomerTextField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.selectedCustomer,
    required this.onFieldSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: 'Customer',
        hintText: 'Search customer by name or phone...',
        prefixIcon: const Icon(Icons.person),
        border: const OutlineInputBorder(),
        errorText: hasError ? 'Please select a customer' : null,
        suffixIcon: selectedCustomer != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              )
            : null,
      ),
      onFieldSubmitted: (_) => onFieldSubmitted(),
    );
  }
}

class _CustomerOptionsView extends StatelessWidget {
  final Iterable<Customer> options;
  final AutocompleteOnSelected<Customer> onSelected;
  final VoidCallback onCreateNew;

  const _CustomerOptionsView({
    required this.options,
    required this.onSelected,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 250,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Create new customer'),
                onTap: onCreateNew,
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final customer = options.elementAt(index);
                    return ListTile(
                      title: Text(customer.name),
                      subtitle: customer.phoneNumber != null
                          ? Text(customer.phoneNumber!)
                          : null,
                      onTap: () => onSelected(customer),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

