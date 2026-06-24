import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';
import '../../../domain/services/measurement_structurer.dart';
import 'editor/garment_section_card.dart';
import 'editor/heading_chips_row.dart';

/// Structured measurement editor: a "+ Garment" chip row, then one
/// [GarmentSectionCard] per [MeasurementSection].
///
/// Value-driven: the parent owns the [StructuredMeasurement] and receives a
/// fresh copy on every edit via [onChanged]. Section internals (controllers,
/// rows, the field picker) live in the `editor/` subfolder.
class StructuredMeasurementEditor extends StatelessWidget {
  final StructuredMeasurement value;
  final ValueChanged<StructuredMeasurement> onChanged;
  final bool enabled;

  const StructuredMeasurementEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  void _addSection(String heading) {
    onChanged(StructuredMeasurement(sections: [
      ...value.sections,
      MeasurementSection(heading: heading, values: const {}),
    ]));
  }

  void _removeSection(int index) {
    onChanged(StructuredMeasurement(
      sections: [...value.sections]..removeAt(index),
    ));
  }

  void _updateSection(int index, MeasurementSection updated) {
    final sections = [...value.sections];
    sections[index] = updated;
    onChanged(StructuredMeasurement(sections: sections));
  }

  @override
  Widget build(BuildContext context) {
    final headings =
        context.watch<SettingsState>().settings.commonGarmentHeadings ??
            DefaultMeasurementFields.defaultHeadings;
    final fields = context.watch<MeasurementFieldsState>().fields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadingChipsRow(
          headings: headings,
          enabled: enabled,
          onTap: _addSection,
        ),
        const SizedBox(height: AppConfig.spacing12),
        if (value.sections.isEmpty)
          EmptyEditorHint(hasHeadings: headings.isNotEmpty)
        else
          for (var i = 0; i < value.sections.length; i++) ...[
            GarmentSectionCard(
              key: ValueKey('section-$i-${value.sections[i].heading}'),
              section: value.sections[i],
              allFields: fields,
              enabled: enabled,
              onChanged: (next) => _updateSection(i, next),
              onDelete: () => _removeSection(i),
            ),
            const SizedBox(height: AppConfig.spacing12),
          ],
      ],
    );
  }
}
