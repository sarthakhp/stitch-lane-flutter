import '../../backend/models/measurement_field.dart';
import '../../constants/gemini_prompts.dart';
import 'gemini_service.dart';
import 'measurement_structurer.dart';
import 'ai_gateway/usage_event.dart';

/// Turns a raw voice transcript into a [StructuredMeasurement] using the LLM's
/// schema-constrained JSON output (see [GeminiPrompts.measurementExtractionSchema]).
///
/// This replaces the old "format to markdown, then regex-parse" path for the
/// measurement flow: the model emits structure directly, which is far more
/// reliable. On any failure (network, bad JSON, empty) the caller falls back
/// to keeping the raw transcript in a notes section — words are never lost,
/// and the audio recording is saved regardless.
class MeasurementExtractor {
  MeasurementExtractor._();

  /// Returns the extracted sections, or null if extraction failed/empty (the
  /// caller should fall back to a notes section with the raw transcript).
  static Future<StructuredMeasurement?> extract(
    String transcript, {
    required List<MeasurementField> fields,
    required List<String> headings,
    String? modelName,
  }) async {
    if (transcript.trim().isEmpty) return null;

    final json = await GeminiService.generateStructured(
      systemInstruction: GeminiPrompts.measurementExtractionSystemInstruction,
      prompt: GeminiPrompts.buildMeasurementExtractionPrompt(
        fields: fields,
        headings: headings,
      ),
      input: transcript,
      schema: GeminiPrompts.measurementExtractionSchema,
      modelName: modelName,
      callerTag: UsageCallerTags.measurementExtract,
    );
    if (json == null) return null;

    final structured = fromExtractionJson(json);
    return structured.isEmpty ? null : structured;
  }

  /// Pure mapper from the extraction JSON shape to [StructuredMeasurement].
  /// Tolerant of missing/extra fields. Extracted here so it's unit-testable
  /// without a network call.
  ///
  /// Input shape: `{ "sections": [ { "heading": str,
  /// "measurements": [ { "label": str, "value": str } ], "notes": str } ] }`.
  static StructuredMeasurement fromExtractionJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    if (rawSections is! List) return StructuredMeasurement.empty();

    final sections = <MeasurementSection>[];
    for (final raw in rawSections) {
      if (raw is! Map) continue;
      final heading = (raw['heading'] ?? '').toString().trim();

      final values = <String, String>{};
      final rawMeasurements = raw['measurements'];
      if (rawMeasurements is List) {
        for (final m in rawMeasurements) {
          if (m is! Map) continue;
          final label = (m['label'] ?? '').toString().trim();
          final value = (m['value'] ?? '').toString().trim();
          if (label.isEmpty) continue;
          values[label] = value;
        }
      }

      final notes = (raw['notes'] ?? '').toString().trim();

      // Drop fully-empty sections (no heading, no values, no notes).
      if (heading.isEmpty && values.isEmpty && notes.isEmpty) continue;
      sections.add(MeasurementSection(
        heading: heading,
        values: values,
        notes: notes,
      ));
    }
    return StructuredMeasurement(sections: sections);
  }
}
