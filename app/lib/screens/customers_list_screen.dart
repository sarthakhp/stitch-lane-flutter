import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../domain/models/customer_filter_preset.dart';
import '../presentation/presentation.dart';

/// Standalone customers route. Thin wrapper over the shared [CustomersBrowser];
/// it brings its own create FAB (unlike the tab, which uses the shell FAB).
class CustomersListScreen extends StatelessWidget {
  final CustomerFilterPreset? initialFilterPreset;
  final bool autoFocusSearch;

  const CustomersListScreen({
    super.key,
    this.initialFilterPreset,
    this.autoFocusSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomersBrowser(
      title: 'Customers',
      initialPreset: initialFilterPreset,
      autoFocusSearch: autoFocusSearch,
      onCreate: () =>
          Navigator.pushNamed(context, AppConstants.customerFormRoute),
    );
  }
}
