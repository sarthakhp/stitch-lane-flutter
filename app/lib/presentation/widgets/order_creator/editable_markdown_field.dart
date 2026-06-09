import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../markdown_description_text.dart';

/// Shows its value as RENDERED markdown (real bullets / bold) with a pencil to
/// switch into raw-text editing — so the draft review matches the final saved
/// order/measurement instead of exposing `- **...**` source text to the tailor.
///
/// Owns its own [TextEditingController] (like the other proposed-* cards) so the
/// caret stays stable when the parent rebuilds for an unrelated reason. Starts
/// in edit mode when empty so the user can type straight away; once there's
/// content it collapses to a tidy preview.
class EditableMarkdownField extends StatefulWidget {
  final String value;
  final bool enabled;
  final String? labelText;
  final String hintText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const EditableMarkdownField({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.labelText,
    this.hintText = '',
    this.minLines = 1,
    this.maxLines = 6,
  });

  @override
  State<EditableMarkdownField> createState() => _EditableMarkdownFieldState();
}

class _EditableMarkdownFieldState extends State<EditableMarkdownField> {
  late final TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _editing = widget.value.trim().isEmpty;
  }

  @override
  void didUpdateWidget(covariant EditableMarkdownField old) {
    super.didUpdateWidget(old);
    // External update (AI refinement round) — sync the controller without
    // clobbering the caret while the user is mid-typing for an unrelated
    // rebuild.
    if (_ctrl.text != widget.value && old.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _enterEdit() {
    setState(() => _editing = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = widget.value.trim().isNotEmpty;

    final label = widget.labelText == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: AppConfig.spacing4),
            child: Text(
              widget.labelText!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          );

    // Edit mode: raw markdown in a text box. Also the resting state when empty.
    if (_editing || !hasContent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) label,
          TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            enabled: widget.enabled,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              suffixIcon: hasContent
                  ? IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      tooltip: 'Done',
                      onPressed: () => setState(() => _editing = false),
                    )
                  : null,
            ),
            onChanged: widget.onChanged,
          ),
        ],
      );
    }

    // Preview mode: rendered markdown + a pencil to edit. Tapping anywhere on
    // the box also enters edit mode.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) label,
        InkWell(
          onTap: widget.enabled ? _enterEdit : null,
          borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacing12,
              vertical: AppConfig.spacing8,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: MarkdownDescriptionText(text: widget.value)),
                if (widget.enabled)
                  Padding(
                    padding: const EdgeInsets.only(left: AppConfig.spacing8),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
