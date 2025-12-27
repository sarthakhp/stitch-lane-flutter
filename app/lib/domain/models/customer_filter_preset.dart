import 'package:flutter/material.dart';
import 'customer_filter_options.dart';

class CustomerFilterPreset {
  final String name;
  final IconData icon;
  final CustomerFilterOptions options;

  const CustomerFilterPreset({
    required this.name,
    required this.icon,
    required this.options,
  });

  static CustomerFilterPreset doneButNotPaid() {
    return const CustomerFilterPreset(
      name: 'Done but Unpaid',
      icon: Icons.money_off,
      options: CustomerFilterOptions(
        showPending: false,
        showReady: false,
        showDone: true,
        showPaid: false,
        showNotPaid: true,
      ),
    );
  }

  static CustomerFilterPreset pending() {
    return const CustomerFilterPreset(
      name: 'Pending',
      icon: Icons.pending_actions,
      options: CustomerFilterOptions(
        showPending: true,
        showReady: false,
        showDone: false,
        showPaid: true,
        showNotPaid: true,
      ),
    );
  }

  static CustomerFilterPreset ready() {
    return const CustomerFilterPreset(
      name: 'Ready',
      icon: Icons.check_circle_outline,
      options: CustomerFilterOptions(
        showPending: false,
        showReady: true,
        showDone: false,
        showPaid: true,
        showNotPaid: true,
      ),
    );
  }

  static CustomerFilterPreset recent() {
    return const CustomerFilterPreset(
      name: 'Recent',
      icon: Icons.schedule,
      options: CustomerFilterOptions.recent(),
    );
  }

  static List<CustomerFilterPreset> get allPresets => [
        recent(),
        doneButNotPaid(),
        pending(),
        ready(),
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerFilterPreset &&
        other.name == name &&
        other.icon == icon &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(name, icon, options);
}

