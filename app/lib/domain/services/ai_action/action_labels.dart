import 'package:intl/intl.dart';

import 'proposed_action.dart';

/// Pure, human-readable labels for a [ProposedAction]. Shared by the action
/// card UI and the post-execution result/history notes so wording stays
/// consistent.
class ActionLabels {
  ActionLabels._();

  /// A short description of the change, independent of which order it targets.
  /// e.g. "Mark as Done", "Record payment of ₹500", "Change due date to 5 Jun 2026".
  static String changeSummary(ProposedAction action) {
    switch (action.kind) {
      case ProposedActionKind.setStatus:
        return 'Mark as ${statusLabel(action.params['status'] as String?)}';
      case ProposedActionKind.recordPayment:
        final amount = action.params['amount'] as int?;
        return amount == null
            ? 'Record full payment'
            : 'Record payment of ₹$amount';
      case ProposedActionKind.setPrice:
        return 'Set price to ₹${action.params['value']}';
      case ProposedActionKind.setDueDate:
        return 'Change due date to ${prettyDate(action.params['dueDate'] as String?)}';
    }
  }

  /// Past-tense summary for a change applied to [count] orders (used when more
  /// than one order was confirmed at once).
  static String resultSummary(ProposedAction action, int count) {
    final n = count == 1 ? '1 order' : '$count orders';
    switch (action.kind) {
      case ProposedActionKind.setStatus:
        return 'Marked $n as ${statusLabel(action.params['status'] as String?)}.';
      case ProposedActionKind.recordPayment:
        return 'Recorded payment on $n.';
      case ProposedActionKind.setPrice:
        return 'Set price on $n.';
      case ProposedActionKind.setDueDate:
        return 'Updated due date on $n.';
    }
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'ready':
        return 'Ready';
      case 'done':
        return 'Done';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  /// Formats an ISO `YYYY-MM-DD` string as "5 Jun 2026"; returns the raw value
  /// if it can't be parsed.
  static String prettyDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : DateFormat('d MMM y').format(parsed);
  }
}
