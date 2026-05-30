import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderValueField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onChanged;

  const OrderValueField({
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
        labelText: 'Order Value (optional)',
        hintText: 'Leave blank if not decided',
        prefixIcon: Icon(Icons.currency_rupee),
        border: OutlineInputBorder(),
        helperText: 'Leave empty for "price not decided"',
      ),
      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      textInputAction: TextInputAction.next,
      enabled: enabled,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
      validator: (value) {
        // Blank is allowed — it means "price not decided" (stored as NULL).
        if (value == null || value.trim().isEmpty) return null;
        if (int.tryParse(value.trim()) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }
}
