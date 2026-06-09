import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/state/main_shell_state.dart';

void main() {
  group('MainShellState tab back-stack', () {
    test('Back returns to the previous tab, then home, then exits', () {
      final s = MainShellState();
      expect(s.selectedIndex, 0); // Home
      expect(s.canPopTab, isFalse);

      s.switchToTab(1); // Orders
      s.switchToTab(2); // Customers
      expect(s.selectedIndex, 2);
      expect(s.canPopTab, isTrue);

      expect(s.popTab(), isTrue);
      expect(s.selectedIndex, 1); // Back → Orders

      expect(s.popTab(), isTrue);
      expect(s.selectedIndex, 0); // Back → Home

      expect(s.canPopTab, isFalse);
      expect(s.popTab(), isFalse); // nothing left → caller lets the OS exit
      expect(s.selectedIndex, 0);
    });

    test('tapping the already-selected tab does not grow history', () {
      final s = MainShellState();
      s.switchToTab(1);
      s.switchToTab(1); // same tab — no-op for history
      expect(s.popTab(), isTrue);
      expect(s.selectedIndex, 0);
      expect(s.canPopTab, isFalse);
    });

    test('filter/voice switches participate in the back-stack', () {
      final s = MainShellState();
      s.switchToOrdersTab(); // 1
      s.switchToAiTab(); // 3
      expect(s.selectedIndex, 3);

      expect(s.popTab(), isTrue);
      expect(s.selectedIndex, 1); // Back → Orders
      expect(s.popTab(), isTrue);
      expect(s.selectedIndex, 0); // Back → Home
      expect(s.canPopTab, isFalse);
    });
  });
}
