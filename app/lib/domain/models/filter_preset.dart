import 'package:flutter/material.dart';
import 'order_filter_options.dart';

class FilterPreset {
  final String name;
  final IconData icon;
  final OrderFilterOptions options;

  const FilterPreset({
    required this.name,
    required this.icon,
    required this.options,
  });

  static FilterPreset doneButNotPaid() {
    return const FilterPreset(
      name: 'Done but Unpaid',
      icon: Icons.money_off,
      options: OrderFilterOptions(
        showPending: false,
        showReady: false,
        showDone: true,
        showPaid: false,
        showNotPaid: true,
      ),
    );
  }

  static FilterPreset allPending() {
    return const FilterPreset(
      name: 'Pending',
      icon: Icons.pending_actions,
      options: OrderFilterOptions(
        showPending: true,
        showReady: false,
        showDone: false,
        showPaid: true,
        showNotPaid: true,
      ),
    );
  }

  static FilterPreset allReady() {
    return const FilterPreset(
      name: 'Ready',
      icon: Icons.check_circle_outline,
      options: OrderFilterOptions(
        showPending: false,
        showReady: true,
        showDone: false,
        showPaid: true,
        showNotPaid: true,
      ),
    );
  }

  static FilterPreset unpaid() {
    return const FilterPreset(
      name: 'Unpaid',
      icon: Icons.money_off,
      options: OrderFilterOptions(
        showPending: true,
        showReady: true,
        showDone: true,
        showPaid: false,
        showNotPaid: true,
      ),
    );
  }

  static List<FilterPreset> get allPresets => [
        doneButNotPaid(),
        allPending(),
        allReady(),
        unpaid(),
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterPreset &&
        other.name == name &&
        other.icon == icon &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(name, icon, options);
}

