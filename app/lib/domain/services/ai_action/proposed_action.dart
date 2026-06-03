/// The write-side counterpart to a read query result: a single change the
/// assistant wants to make, staged for the user to confirm. The model never
/// writes — it only produces one of these via a `propose_*` tool call.

/// The kind of change being proposed.
enum ProposedActionKind { setStatus, recordPayment, setPrice, setDueDate }

/// Lifecycle of a proposed action in the UI.
enum ActionStatus { proposed, done, cancelled, failed }

/// A tappable order candidate shown when the model could not pin down exactly
/// one order. Carries its own display fields so the action package stays
/// independent of the chat's [UiComponent] navigation model.
class ActionCandidate {
  final String orderId;

  /// Customer name (headline).
  final String title;

  /// Distinguishing lines: phone, order title, ₹value, due date.
  final List<String> lines;

  /// Local image paths for the order (shown as thumbnails).
  final List<String> imagePaths;

  const ActionCandidate({
    required this.orderId,
    required this.title,
    this.lines = const [],
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'title': title,
        if (lines.isNotEmpty) 'lines': lines,
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };

  factory ActionCandidate.fromJson(Map<String, dynamic> json) =>
      ActionCandidate(
        orderId: json['orderId'] as String,
        title: json['title'] as String,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

/// A staged change. [params] are typed by [kind]:
/// - setStatus:    {'status': 'pending'|'ready'|'done'}
/// - recordPayment:{'amount': int?}  (absent ⇒ pay full remaining)
/// - setPrice:     {'value': int}
/// - setDueDate:   {'dueDate': 'YYYY-MM-DD'}
class ProposedAction {
  final String id;
  final ProposedActionKind kind;
  final Map<String, dynamic> params;

  /// Orders the change may apply to. The user ticks one or many on the card;
  /// the change is applied to every ticked order.
  final List<String> candidateOrderIds;

  /// Enriched display for each candidate, filled after the model replies.
  final List<ActionCandidate> candidates;

  final ActionStatus status;

  /// Outcome message after execution (success or failure).
  final String? resultMessage;

  /// Orders the change was actually applied to (set on confirm), so the done
  /// card keeps showing what was done and which orders were affected.
  final List<String> executedOrderIds;

  const ProposedAction({
    required this.id,
    required this.kind,
    required this.params,
    required this.candidateOrderIds,
    this.candidates = const [],
    this.status = ActionStatus.proposed,
    this.resultMessage,
    this.executedOrderIds = const [],
  });

  /// True when two proposals express the same change (kind + params),
  /// regardless of which orders — used to merge them into a single card.
  bool sameChange(ProposedAction other) {
    if (kind != other.kind) return false;
    if (params.length != other.params.length) return false;
    for (final entry in params.entries) {
      if (other.params[entry.key] != entry.value) return false;
    }
    return true;
  }

  ProposedAction copyWith({
    List<String>? candidateOrderIds,
    List<ActionCandidate>? candidates,
    ActionStatus? status,
    String? resultMessage,
    List<String>? executedOrderIds,
  }) {
    return ProposedAction(
      id: id,
      kind: kind,
      params: params,
      candidateOrderIds: candidateOrderIds ?? this.candidateOrderIds,
      candidates: candidates ?? this.candidates,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
      executedOrderIds: executedOrderIds ?? this.executedOrderIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'params': params,
        'candidateOrderIds': candidateOrderIds,
        'candidates': candidates.map((c) => c.toJson()).toList(),
        'status': status.name,
        if (resultMessage != null) 'resultMessage': resultMessage,
        if (executedOrderIds.isNotEmpty) 'executedOrderIds': executedOrderIds,
      };

  factory ProposedAction.fromJson(Map<String, dynamic> json) => ProposedAction(
        id: json['id'] as String,
        kind: ProposedActionKind.values.firstWhere(
          (e) => e.name == json['kind'],
          orElse: () => ProposedActionKind.setStatus,
        ),
        params: Map<String, dynamic>.from(json['params'] as Map),
        candidateOrderIds: (json['candidateOrderIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        candidates: (json['candidates'] as List<dynamic>?)
                ?.map((c) => ActionCandidate.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        status: ActionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ActionStatus.proposed,
        ),
        resultMessage: json['resultMessage'] as String?,
        // Back-compat: older chats stored a single executedOrderId.
        executedOrderIds: (json['executedOrderIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            (json['executedOrderId'] != null
                ? [json['executedOrderId'] as String]
                : const []),
      );
}
