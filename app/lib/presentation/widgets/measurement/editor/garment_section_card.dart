import 'package:flutter/material.dart';

import '../../../../backend/backend.dart';
import '../../../../config/app_config.dart';
import '../../../../domain/services/measurement_structurer.dart';
import 'field_picker_sheet.dart';
import 'measurement_field_row.dart';

/// One editable garment: editable heading, a row per measurement, an "Add
/// measurement" picker over the global fields, and per-section notes.
///
/// Owns a [TextEditingController] per visible text field so typing doesn't
/// lose focus on parent rebuilds; emits an updated [MeasurementSection] via
/// [onChanged]. Value-driven — holds no domain state of its own.
class GarmentSectionCard extends StatefulWidget {
  final MeasurementSection section;
  final List<MeasurementField> allFields;
  final bool enabled;
  final ValueChanged<MeasurementSection> onChanged;
  final VoidCallback onDelete;

  const GarmentSectionCard({
    super.key,
    required this.section,
    required this.allFields,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<GarmentSectionCard> createState() => _GarmentSectionCardState();
}

class _GarmentSectionCardState extends State<GarmentSectionCard> {
  late final TextEditingController _heading;
  late final TextEditingController _notes;
  // One controller per row so re-renders don't lose focus / cursor position.
  final Map<String, TextEditingController> _valueControllers = {};

  @override
  void initState() {
    super.initState();
    _heading = TextEditingController(text: widget.section.heading);
    _notes = TextEditingController(text: widget.section.notes);
    _syncValueControllers(widget.section.values);
  }

  @override
  void didUpdateWidget(covariant GarmentSectionCard old) {
    super.didUpdateWidget(old);
    if (old.section.heading != widget.section.heading &&
        _heading.text != widget.section.heading) {
      _heading.text = widget.section.heading;
    }
    if (old.section.notes != widget.section.notes &&
        _notes.text != widget.section.notes) {
      _notes.text = widget.section.notes;
    }
    _syncValueControllers(widget.section.values);
  }

  void _syncValueControllers(Map<String, String> values) {
    final removed =
        _valueControllers.keys.where((k) => !values.containsKey(k)).toList();
    for (final k in removed) {
      _valueControllers.remove(k)?.dispose();
    }
    values.forEach((label, value) {
      final existing = _valueControllers[label];
      if (existing == null) {
        _valueControllers[label] = TextEditingController(text: value);
      } else if (existing.text != value) {
        existing.text = value;
      }
    });
  }

  @override
  void dispose() {
    _heading.dispose();
    _notes.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit({Map<String, String>? values, String? heading, String? notes}) {
    widget.onChanged(widget.section.copyWith(
      heading: heading,
      values: values,
      notes: notes,
    ));
  }

  void _setValue(String label, String value) {
    _emit(values: Map<String, String>.from(widget.section.values)
      ..[label] = value);
  }

  void _removeRow(String label) {
    _valueControllers.remove(label)?.dispose();
    _emit(values: Map<String, String>.from(widget.section.values)..remove(label));
  }

  Future<void> _openFieldPicker() async {
    final used = widget.section.values.keys.map((k) => k.toLowerCase()).toSet();
    final available = widget.allFields
        .where((f) => !used.contains(f.label.toLowerCase()))
        .toList();
    final picked = await showModalBottomSheet<FieldPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FieldPickerSheet(available: available),
    );
    if (picked == null) return;
    if (widget.section.values.containsKey(picked.label)) return;
    _emit(values: Map<String, String>.from(widget.section.values)
      ..[picked.label] = '');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppConfig.spacing4),
            const Divider(height: 1),
            const SizedBox(height: AppConfig.spacing4),
            for (final entry in widget.section.values.entries)
              MeasurementFieldRow(
                key: ValueKey('row-${entry.key}'),
                label: entry.key,
                controller: _valueControllers[entry.key]!,
                enabled: widget.enabled,
                onChanged: (v) => _setValue(entry.key, v),
                onRemove: () => _removeRow(entry.key),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add measurement'),
                onPressed: widget.enabled ? _openFieldPicker : null,
              ),
            ),
            const SizedBox(height: AppConfig.spacing8),
            _buildNotesField(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppConfig.spacing8),
        Expanded(
          child: TextField(
            controller: _heading,
            enabled: widget.enabled,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Garment',
              isDense: true,
              border: InputBorder.none,
            ),
            onChanged: (v) => _emit(heading: v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove section',
          visualDensity: VisualDensity.compact,
          onPressed: widget.enabled ? widget.onDelete : null,
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notes,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Notes',
        hintText: 'Anything else about this garment…',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => _emit(notes: v),
    );
  }
}
