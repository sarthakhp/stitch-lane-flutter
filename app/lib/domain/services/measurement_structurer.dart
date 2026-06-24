/// In-memory representation of a measurement section.
///
/// One section = one garment block ("Blouse", "Pant", …).
class MeasurementSection {
  final String heading;
  final Map<String, String> values;
  final String notes;

  const MeasurementSection({
    required this.heading,
    required this.values,
    this.notes = '',
  });

  MeasurementSection copyWith({
    String? heading,
    Map<String, String>? values,
    String? notes,
  }) {
    return MeasurementSection(
      heading: heading ?? this.heading,
      values: values ?? this.values,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'values': values,
        'notes': notes,
      };

  factory MeasurementSection.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final values = <String, String>{};
    if (rawValues is Map) {
      rawValues.forEach((k, v) {
        values[k.toString()] = v?.toString() ?? '';
      });
    }
    return MeasurementSection(
      heading: (json['heading'] ?? '').toString(),
      values: values,
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class StructuredMeasurement {
  final List<MeasurementSection> sections;

  const StructuredMeasurement({required this.sections});

  bool get isEmpty => sections.isEmpty;

  Map<String, dynamic> toJson() => {
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory StructuredMeasurement.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'];
    final out = <MeasurementSection>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          out.add(MeasurementSection.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return StructuredMeasurement(sections: out);
  }

  factory StructuredMeasurement.empty() =>
      const StructuredMeasurement(sections: []);
}

/// Converts between the markdown shape used in [Measurement.description] and
/// the structured shape used by the form editor + AI ingestion.
///
/// Markdown shape (what existing measurements use, and what the AI emits):
///
///     **Blouse**:
///     - Length: 13.5
///     - Full Bust: 34.5
///     - *Loose at waist*
///
///     **Pant**:
///     - Waist: 30
///
/// Field labels are matched against [MeasurementField.label] and
/// [MeasurementField.aliases] case-insensitively; matched rows get the
/// canonical label, unmatched rows keep the user-typed/AI-emitted label
/// (they still go into [MeasurementSection.values]). Italic-only lines and
/// any bare text become [MeasurementSection.notes].
class MeasurementStructurer {
  MeasurementStructurer._();

  /// Wrap a legacy free-text/markdown description (from a pre-feature
  /// measurement) into a single notes-only section, so it can be loaded into
  /// the structured editor without lossy parsing. The original text is kept
  /// verbatim in the section's notes; the user can re-key values into fields
  /// if they want structure. Empty input yields an empty structure.
  static StructuredMeasurement fromLegacyText(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return StructuredMeasurement.empty();
    return StructuredMeasurement(sections: [
      MeasurementSection(heading: '', values: const {}, notes: trimmed),
    ]);
  }

  /// Merge [incoming] sections into [current]: sections sharing a heading
  /// (case-insensitive) merge their values (incoming wins on conflicts) and
  /// concatenate notes; new headings are appended. Used when a fresh dictation
  /// is folded into what's already in the form.
  static StructuredMeasurement mergeSections(
    StructuredMeasurement current,
    StructuredMeasurement incoming,
  ) {
    final byHeading = <String, int>{
      for (var i = 0; i < current.sections.length; i++)
        current.sections[i].heading.toLowerCase().trim(): i,
    };
    final next = [...current.sections];
    for (final section in incoming.sections) {
      final key = section.heading.toLowerCase().trim();
      final idx = byHeading[key];
      if (idx == null) {
        next.add(section);
        byHeading[key] = next.length - 1;
      } else {
        final existing = next[idx];
        final mergedNotes = [
          if (existing.notes.trim().isNotEmpty) existing.notes.trim(),
          if (section.notes.trim().isNotEmpty) section.notes.trim(),
        ].join('\n');
        next[idx] = existing.copyWith(
          values: Map<String, String>.from(existing.values)
            ..addAll(section.values),
          notes: mergedNotes,
        );
      }
    }
    return StructuredMeasurement(sections: next);
  }

  /// Render structured sections back to markdown. This is the canonical
  /// derivation of a measurement's `description` from its structure — used for
  /// backup, search, list previews, and AI queries.
  static String serialize(StructuredMeasurement structured) {
    final buffers = <String>[];
    for (final section in structured.sections) {
      final heading = section.heading.trim();
      final lines = <String>[];
      if (heading.isNotEmpty) lines.add('**$heading**:');
      section.values.forEach((label, value) {
        if (label.trim().isEmpty) return;
        lines.add('- $label: $value');
      });
      final notes = section.notes.trim();
      if (notes.isNotEmpty) {
        for (final n in notes.split('\n')) {
          final t = n.trim();
          if (t.isEmpty) continue;
          lines.add('- *$t*');
        }
      }
      if (lines.isNotEmpty) buffers.add(lines.join('\n'));
    }
    return buffers.join('\n\n');
  }
}
