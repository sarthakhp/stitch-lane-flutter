import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../domain/models/customer_filter_preset.dart';
import '../../presentation/presentation.dart';

/// The main Customers tab. A thin wrapper over the shared [CustomersBrowser];
/// the shell drives external filters (e.g. a home KPI tap) through
/// [applyFilter].
class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => CustomersTabState();
}

class CustomersTabState extends State<CustomersTab> {
  final _browserKey = GlobalKey<CustomersBrowserState>();
  CustomerFilterPreset _preset = CustomerFilterPreset.recent();

  /// Invoked by the shell (via GlobalKey) to apply a filter requested from
  /// another screen. Forwards to the live browser, or seeds the initial preset
  /// if the browser hasn't mounted yet.
  void applyFilter(CustomerFilterPreset preset) {
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
    return CustomersBrowser(
      key: _browserKey,
      title: 'Customers',
      initialPreset: _preset,
      onCreate: () =>
          Navigator.pushNamed(context, AppConstants.customerFormRoute),
    );
  }
}
