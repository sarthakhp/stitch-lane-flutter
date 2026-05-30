import 'package:uuid/uuid.dart';

/// One order the AI agent has proposed but the tailor has not yet committed.
/// Identical shape to an [Order] minus the persisted fields (status/createdAt
/// get filled in at commit time). The [id] is ephemeral and only used by the
/// agent + UI to refer to the same draft row across turns.
class ProposedOrder {
  final String id;
  final String? title;

  /// Price in rupees. Null means "price not decided yet" (distinct from 0).
  final int? value;
  final DateTime dueDate;
  final String? description;

  const ProposedOrder({
    required this.id,
    required this.title,
    required this.value,
    required this.dueDate,
    required this.description,
  });

  ProposedOrder copyWith({
    String? title,
    bool clearTitle = false,
    int? value,
    bool clearValue = false,
    DateTime? dueDate,
    String? description,
    bool clearDescription = false,
  }) {
    return ProposedOrder(
      id: id,
      title: clearTitle ? null : (title ?? this.title),
      value: clearValue ? null : (value ?? this.value),
      dueDate: dueDate ?? this.dueDate,
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'value': value,
        'due_date': dueDate.toIso8601String(),
        'description': description,
      };

  static String generateId() => const Uuid().v4();
}

/// One measurement record the AI agent has proposed. Measurements are
/// customer-scoped (not tied to an order or garment type) and the description
/// is rich markdown text covering one or more garments.
class ProposedMeasurement {
  final String id;
  final String description;

  const ProposedMeasurement({
    required this.id,
    required this.description,
  });

  ProposedMeasurement copyWith({String? description}) {
    return ProposedMeasurement(
      id: id,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
      };

  static String generateId() => const Uuid().v4();
}

/// Snapshot of everything the agent has built so far. Immutable — every
/// mutation produces a new draft, which makes it cheap to log, diff, and
/// pass into the next agent turn as context.
class OrderProposalDraft {
  final List<ProposedOrder> orders;
  final List<ProposedMeasurement> measurements;

  const OrderProposalDraft({
    this.orders = const [],
    this.measurements = const [],
  });

  static const empty = OrderProposalDraft();

  bool get isEmpty => orders.isEmpty && measurements.isEmpty;
  bool get hasOrders => orders.isNotEmpty;
  bool get hasMeasurement => measurements.isNotEmpty;

  OrderProposalDraft copyWith({
    List<ProposedOrder>? orders,
    List<ProposedMeasurement>? measurements,
  }) {
    return OrderProposalDraft(
      orders: orders ?? this.orders,
      measurements: measurements ?? this.measurements,
    );
  }

  Map<String, dynamic> toJson() => {
        'orders': orders.map((o) => o.toJson()).toList(),
        'measurements': measurements.map((m) => m.toJson()).toList(),
      };
}

/// One row in the agent's transcript-of-actions. Surfaced in the UI so the
/// tailor can see what the AI is doing (and so we have a debuggable trail).
enum AgentLogKind { toolCall, toolResult, agentText, info, error }

class AgentLogEntry {
  final DateTime timestamp;
  final AgentLogKind kind;
  final String label;
  final Map<String, dynamic>? data;

  AgentLogEntry({
    required this.kind,
    required this.label,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
