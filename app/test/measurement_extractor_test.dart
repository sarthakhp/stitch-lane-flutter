import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/measurement_extractor.dart';

void main() {
  group('MeasurementExtractor.fromExtractionJson', () {
    test('maps sections + measurement pairs into values', () {
      final out = MeasurementExtractor.fromExtractionJson({
        'sections': [
          {
            'heading': 'Blouse',
            'measurements': [
              {'label': 'Length', 'value': '13.5'},
              {'label': 'Mori', 'value': '10'},
            ],
            'notes': 'loose at waist',
          },
        ],
      });
      expect(out.sections, hasLength(1));
      final s = out.sections.single;
      expect(s.heading, 'Blouse');
      expect(s.values, {'Length': '13.5', 'Mori': '10'});
      expect(s.notes, 'loose at waist');
    });

    test('drops blank measurement labels but keeps the section', () {
      final out = MeasurementExtractor.fromExtractionJson({
        'sections': [
          {
            'heading': 'Top',
            'measurements': [
              {'label': '', 'value': '9'},
              {'label': 'Waist', 'value': '30'},
            ],
            'notes': '',
          },
        ],
      });
      expect(out.sections.single.values, {'Waist': '30'});
    });

    test('skips fully-empty sections', () {
      final out = MeasurementExtractor.fromExtractionJson({
        'sections': [
          {'heading': '', 'measurements': [], 'notes': ''},
          {
            'heading': 'Pant',
            'measurements': [
              {'label': 'Waist', 'value': '41'}
            ],
            'notes': '',
          },
        ],
      });
      expect(out.sections, hasLength(1));
      expect(out.sections.single.heading, 'Pant');
    });

    test('tolerates malformed / missing fields without throwing', () {
      expect(MeasurementExtractor.fromExtractionJson({}).isEmpty, isTrue);
      expect(
        MeasurementExtractor.fromExtractionJson({'sections': 'nope'}).isEmpty,
        isTrue,
      );
      final partial = MeasurementExtractor.fromExtractionJson({
        'sections': [
          {'heading': 'X'} // no measurements/notes keys
        ],
      });
      expect(partial.sections.single.heading, 'X');
      expect(partial.sections.single.values, isEmpty);
    });
  });
}
