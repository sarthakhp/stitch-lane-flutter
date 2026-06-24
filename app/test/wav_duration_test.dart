import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/utils/wav_duration.dart';

void main() {
  group('WavDuration.fromBytes (size → seconds, no decode)', () {
    test('1 second = header + 32000 bytes', () {
      expect(WavDuration.fromBytes(44 + 32000), const Duration(seconds: 1));
    });

    test('10 seconds', () {
      expect(WavDuration.fromBytes(44 + 320000), const Duration(seconds: 10));
    });

    test('header-only / empty is zero, not negative', () {
      expect(WavDuration.fromBytes(44), Duration.zero);
      expect(WavDuration.fromBytes(0), Duration.zero);
    });
  });
}
