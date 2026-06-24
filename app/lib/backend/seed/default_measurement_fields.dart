import 'package:uuid/uuid.dart';

import '../models/measurement_field.dart';

/// Default field set + heading set, derived from analysis of 87 real
/// measurements in the user's backup. See conversation notes for the
/// frequency table.
///
/// These are seeded once on first run (or when the user taps "Restore
/// defaults") into the global flat field list. Headings are stored on
/// [AppSettings.commonGarmentHeadings] and serve only as an AI hint —
/// they don't constrain what sections the user/AI can create.
class DefaultMeasurementFields {
  DefaultMeasurementFields._();

  /// (label, aliases) tuples in display order.
  static const List<(String, List<String>)> _defaults = [
    ('Length', []),
    ('Upper Bust', []),
    ('Full Bust', []),
    ('Bust', []),
    ('Bust Point', []),
    ('Waist', []),
    ('Waist Length', []),
    ('Hip', []),
    ('Shoulder', []),
    ('Armhole', []),
    ('Bicep', ['Biceps']),
    ('Sleeve Length', []),
    ('Mori', ['મોરી']),
    ('Sleeve Mori', ['Sleeve મોરી']),
    ('Front Neck', []),
    ('Back Neck', []),
    ('Hook', []),
    ('Thigh', ['Thighs']),
    ('Knee Round', ['Knee']),
    ('Calf', ['પિંડલી Round', 'Pindli Round']),
  ];

  static const List<String> defaultHeadings = [
    'Blouse',
    'Top',
    'Pant',
    'Plazzo',
    'Salwar',
    'Skirt',
    'Kurta',
    'Dress',
    'Gown',
  ];

  static List<MeasurementField> build() {
    const uuid = Uuid();
    final out = <MeasurementField>[];
    for (var i = 0; i < _defaults.length; i++) {
      final (label, aliases) = _defaults[i];
      out.add(MeasurementField(
        id: uuid.v4(),
        label: label,
        aliases: aliases,
        sortOrder: i,
      ));
    }
    return out;
  }
}
