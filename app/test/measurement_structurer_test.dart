import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/measurement_structurer.dart';

void main() {
  group('serialize (derives description from structure)', () {
    test('renders headings, values, and italic notes', () {
      const structured = StructuredMeasurement(sections: [
        MeasurementSection(
          heading: 'Blouse',
          values: {'Length': '13.5', 'Full Bust': '34.5'},
          notes: 'Loose at waist',
        ),
        MeasurementSection(heading: 'Pant', values: {'Waist': '30'}, notes: ''),
      ]);
      final out = MeasurementStructurer.serialize(structured);
      expect(
        out,
        '**Blouse**:\n'
        '- Length: 13.5\n'
        '- Full Bust: 34.5\n'
        '- *Loose at waist*\n\n'
        '**Pant**:\n'
        '- Waist: 30',
      );
    });

    test('empty structure serializes to empty string', () {
      expect(MeasurementStructurer.serialize(StructuredMeasurement.empty()), '');
    });

    test('JSON round-trip preserves sections', () {
      const structured = StructuredMeasurement(sections: [
        MeasurementSection(
          heading: 'Top',
          values: {'Length': '41', 'Mori': '11'},
          notes: 'note',
        ),
      ]);
      final back = StructuredMeasurement.fromJson(structured.toJson());
      expect(back.sections.single.heading, 'Top');
      expect(back.sections.single.values, {'Length': '41', 'Mori': '11'});
      expect(back.sections.single.notes, 'note');
    });
  });

  group('mergeSections (folding a new dictation into the form)', () {
    test('same heading merges values (incoming wins) and joins notes', () {
      const current = StructuredMeasurement(sections: [
        MeasurementSection(
            heading: 'Blouse', values: {'Length': '13', 'Waist': '30'}, notes: 'a'),
      ]);
      const incoming = StructuredMeasurement(sections: [
        MeasurementSection(
            heading: 'blouse', values: {'Waist': '31', 'Mori': '10'}, notes: 'b'),
      ]);
      final merged = MeasurementStructurer.mergeSections(current, incoming);
      expect(merged.sections, hasLength(1));
      expect(merged.sections.single.values,
          {'Length': '13', 'Waist': '31', 'Mori': '10'});
      expect(merged.sections.single.notes, 'a\nb');
    });

    test('new heading is appended', () {
      const current = StructuredMeasurement(sections: [
        MeasurementSection(heading: 'Blouse', values: {'Length': '13'}, notes: ''),
      ]);
      const incoming = StructuredMeasurement(sections: [
        MeasurementSection(heading: 'Pant', values: {'Waist': '30'}, notes: ''),
      ]);
      final merged = MeasurementStructurer.mergeSections(current, incoming);
      expect(merged.sections.map((s) => s.heading), ['Blouse', 'Pant']);
    });
  });

  group('fromLegacyText (old markdown measurement → notes, lossless)', () {
    test('keeps the whole legacy description verbatim in one notes section', () {
      const legacy = '**Top**:\n- Length: 41\n- મોરી: 11\n\nloose at waist';
      final out = MeasurementStructurer.fromLegacyText(legacy);
      expect(out.sections, hasLength(1));
      expect(out.sections.single.heading, isEmpty);
      expect(out.sections.single.values, isEmpty);
      expect(out.sections.single.notes, legacy); // nothing parsed, nothing lost
    });

    test('empty/whitespace legacy text yields an empty structure', () {
      expect(MeasurementStructurer.fromLegacyText('   ').isEmpty, isTrue);
      expect(MeasurementStructurer.fromLegacyText('').isEmpty, isTrue);
    });
  });
}
