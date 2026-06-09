import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/utils/dispose_safe_notifier.dart';

class _Probe extends ChangeNotifier with DisposeSafeNotifier {
  void ping() => safeNotify();
}

void main() {
  group('DisposeSafeNotifier', () {
    test('safeNotify notifies before dispose', () {
      final probe = _Probe();
      var count = 0;
      probe.addListener(() => count++);

      expect(probe.isDisposed, isFalse);
      probe.ping();
      expect(count, 1);
      probe.dispose();
    });

    test('after dispose: isDisposed is true and safeNotify is a silent no-op',
        () {
      final probe = _Probe();
      var count = 0;
      probe.addListener(() => count++);
      probe.ping();
      expect(count, 1);

      probe.dispose();
      expect(probe.isDisposed, isTrue);

      // The whole point: a late callback must NOT throw
      // "used after being disposed", and must not fire listeners.
      expect(probe.ping, returnsNormally);
      expect(count, 1);
    });
  });
}
