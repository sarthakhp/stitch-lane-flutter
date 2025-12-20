enum CustomerSort {
  dueDate,
  orderCount,
  pendingAmount,
}

extension CustomerSortExtension on CustomerSort {
  String get displayName {
    switch (this) {
      case CustomerSort.dueDate:
        return 'Sort by: Due Date';
      case CustomerSort.orderCount:
        return 'Sort by: Pending Orders';
      case CustomerSort.pendingAmount:
        return 'Sort by: Pending Amount';
    }
  }
}

