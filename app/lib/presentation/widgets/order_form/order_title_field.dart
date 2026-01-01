import 'package:flutter/material.dart';
import '../../../domain/validators/order_validators.dart';

class OrderTitleField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onChanged;

  const OrderTitleField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Title (Optional)',
        hintText: 'Enter order title',
        prefixIcon: Icon(Icons.assignment),
        border: OutlineInputBorder(),
      ),
      validator: OrderValidators.validateTitle,
      textInputAction: TextInputAction.next,
      enabled: enabled,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
    );
  }
}

