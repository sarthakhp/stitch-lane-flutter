import 'package:flutter/foundation.dart';
import '../models/filter_preset.dart';
import '../models/customer_filter_preset.dart';

/// Drives the bottom-nav shell: which tab is showing, one-shot payloads handed
/// to a tab when it's switched to (a filter preset, "open the mic"), and a
/// back-stack of visited tabs so the system back button returns to the
/// PREVIOUS tab rather than always jumping home.
///
/// Back behaviour: Home → Orders → Customers, then Back → Orders → Home →
/// (exit). Once the tab history is empty the shell is the root route, so the
/// OS pop exits the app.
class MainShellState extends ChangeNotifier {
  int _selectedIndex = 0;
  FilterPreset? _pendingOrdersFilter;
  CustomerFilterPreset? _pendingCustomersFilter;
  bool _pendingAiVoice = false;

  /// Tabs we've navigated away from, in visit order. [popTab] walks this.
  final List<int> _tabHistory = [];

  int get selectedIndex => _selectedIndex;

  /// Whether a system back press should return to a previous tab (true) rather
  /// than popping the root shell route / exiting the app (false).
  bool get canPopTab => _tabHistory.isNotEmpty;

  FilterPreset? consumeOrdersFilter() {
    final filter = _pendingOrdersFilter;
    _pendingOrdersFilter = null;
    return filter;
  }

  CustomerFilterPreset? consumeCustomersFilter() {
    final filter = _pendingCustomersFilter;
    _pendingCustomersFilter = null;
    return filter;
  }

  /// One-shot: whether the AI tab should open its mic (set when launched from
  /// the home-screen widget's "Chat" button).
  bool consumeAiVoice() {
    final v = _pendingAiVoice;
    _pendingAiVoice = false;
    return v;
  }

  void switchToTab(int index) => _select(index);

  void switchToOrdersTab({FilterPreset? filter}) {
    _pendingOrdersFilter = filter;
    _select(1);
  }

  void switchToCustomersTab({CustomerFilterPreset? filter}) {
    _pendingCustomersFilter = filter;
    _select(2);
  }

  void switchToAiTab({bool startVoice = false}) {
    _pendingAiVoice = startVoice;
    _select(3);
  }

  /// System back: return to the previously-visited tab. Returns false when
  /// there's no history left, so the caller can let the OS pop (exit the app).
  bool popTab() {
    if (_tabHistory.isEmpty) return false;
    _selectedIndex = _tabHistory.removeLast();
    notifyListeners();
    return true;
  }

  /// Switch to [index], remembering the tab we're leaving so Back can return
  /// to it. Always notifies so a pending filter / voice payload is delivered
  /// even when we're already on [index].
  void _select(int index) {
    if (_selectedIndex != index) {
      _tabHistory.add(_selectedIndex);
      _selectedIndex = index;
    }
    notifyListeners();
  }
}
