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

    test('toJson emits an explicit valueOrder alongside values', () {
      const section = MeasurementSection(
        heading: 'Top',
        values: {'Length': '41', 'Mori': '11', 'Waist': '30'},
      );
      expect(section.toJson()['valueOrder'], ['Length', 'Mori', 'Waist']);
    });

    test('fromJson restores order from valueOrder, ignoring the map\'s own key '
        'order — the shape a value survives a Firestore round-trip in, since '
        'map fields there don\'t guarantee key order is preserved', () {
      final section = MeasurementSection.fromJson({
        'heading': 'Top',
        // Deliberately out of order vs. valueOrder below.
        'values': {'Waist': '30', 'Length': '41', 'Mori': '11'},
        'valueOrder': ['Length', 'Mori', 'Waist'],
        'notes': '',
      });
      expect(section.values.keys.toList(), ['Length', 'Mori', 'Waist']);
    });

    test('fromJson falls back to the map\'s own order when valueOrder is '
        'absent — old measurements saved before this field existed', () {
      final section = MeasurementSection.fromJson({
        'heading': 'Top',
        'values': {'Waist': '30', 'Length': '41'},
        'notes': '',
      });
      expect(section.values.keys.toList(), ['Waist', 'Length']);
    });

    test('fromJson appends keys missing from valueOrder instead of dropping '
        'them — defensive against a partial/stale order list', () {
      final section = MeasurementSection.fromJson({
        'heading': 'Top',
        'values': {'Waist': '30', 'Length': '41', 'Mori': '11'},
        'valueOrder': ['Length'],
        'notes': '',
      });
      expect(section.values.keys.toList(), ['Length', 'Waist', 'Mori']);
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
