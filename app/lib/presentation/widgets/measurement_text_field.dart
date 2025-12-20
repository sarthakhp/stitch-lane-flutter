import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class MeasurementTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final VoidCallback? onChanged;

  const MeasurementTextField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  State<MeasurementTextField> createState() => _MeasurementTextFieldState();
}

class _MeasurementTextFieldState extends State<MeasurementTextField> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Measurement Description',
            hintText: 'Enter measurement details...',
            border: const OutlineInputBorder(),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call();
                    },
                    tooltip: 'Clear description',
                  )
                : null,
          ),
          style: const TextStyle(
            fontSize: AppConfig.measurementDescriptionFontSize,
          ),
          minLines: 3,
          maxLines: null,
          validator: widget.validator,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => widget.onChanged?.call(),
        );
      },
    );
  }
}

