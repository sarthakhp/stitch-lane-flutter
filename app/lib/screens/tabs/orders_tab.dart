import 'package:flutter/material.dart';

import '../../domain/models/filter_preset.dart';
import '../../presentation/presentation.dart';

/// The main Orders tab. A thin wrapper over the shared [OrdersBrowser]; the
/// shell drives external filters (e.g. a home KPI tap) through [applyFilter].
/// Creation is handled by the shell FAB, so no sticky create button here.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => OrdersTabState();
}

class OrdersTabState extends State<OrdersTab> {
  final _browserKey = GlobalKey<OrdersBrowserState>();
  FilterPreset _preset = FilterPreset.recent();

  /// Invoked by the shell (via GlobalKey) to apply a filter requested from
  /// another screen. Forwards to the live browser, or seeds the initial preset
  /// if the browser hasn't mounted yet.
  void applyFilter(FilterPreset preset) {
    _preset = preset;
    final browser = _browserKey.currentState;
    if (browser != null) {
      browser.applyExternalFilter(preset);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrdersBrowser(
      key: _browserKey,
      title: 'Orders',
      initialPreset: _preset,
    );
  }
}
