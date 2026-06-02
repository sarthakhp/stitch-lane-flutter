import 'package:flutter/foundation.dart';
import '../models/filter_preset.dart';
import '../models/customer_filter_preset.dart';

class MainShellState extends ChangeNotifier {
  int _selectedIndex = 0;
  FilterPreset? _pendingOrdersFilter;
  CustomerFilterPreset? _pendingCustomersFilter;

  int get selectedIndex => _selectedIndex;
  
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

  void switchToTab(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void switchToOrdersTab({FilterPreset? filter}) {
    _pendingOrdersFilter = filter;
    _selectedIndex = 1;
    notifyListeners();
  }

  void switchToCustomersTab({CustomerFilterPreset? filter}) {
    _pendingCustomersFilter = filter;
    _selectedIndex = 2;
    notifyListeners();
  }

  bool _pendingAiVoice = false;

  /// One-shot: whether the AI tab should open its mic (set when launched from
  /// the home-screen widget's "Chat" button).
  bool consumeAiVoice() {
    final v = _pendingAiVoice;
    _pendingAiVoice = false;
    return v;
  }

  void switchToAiTab({bool startVoice = false}) {
    _pendingAiVoice = startVoice;
    _selectedIndex = 3;
    notifyListeners();
  }

  void switchToHomeTab() {
    _selectedIndex = 0;
    notifyListeners();
  }
}

