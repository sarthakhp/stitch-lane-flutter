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
        labelText: 'Order Value',
        hintText: 'Enter order value',
        prefixIcon: Icon(Icons.currency_rupee),
        border: OutlineInputBorder(),
        helperText: 'Enter positive, negative, or zero value',
      ),
      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
      textInputAction: TextInputAction.next,
      enabled: enabled,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
    );
  }
}

