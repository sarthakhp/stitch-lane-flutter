import 'package:uuid/uuid.dart';

import 'ai_action_tools.dart';
import 'proposed_action.dart';

/// Turns a `propose_*` tool call (name + arguments) into a [ProposedAction].
/// This is the single place the executor branches between read tools (which
/// run via the query dispatcher) and write tools (which only stage a change).
class ProposedActionFactory {
  ProposedActionFactory._();

  /// Result handed back to the model after staging, so it stops calling tools
  /// and writes a natural confirmation sentence. Nothing was written.
  static const String stagedToolResult =
      '{"staged": true, "note": "Staged successfully. Do NOT call any more tools. '
      'Now reply with one short confirmation sentence and an empty ui_components."}';

  static bool isActionTool(String name) => AiActionToolNames.all.contains(name);

  /// Build a staged action from a known `propose_*` tool call. Caller must
  /// guard with [isActionTool] first.
  static ProposedAction build(String name, Map<String, dynamic> args) {
    final orderIds = (args['orderIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final (kind, params) = switch (name) {
      AiActionToolNames.proposeSetStatus => (
          ProposedActionKind.setStatus,
          {'status': args['status'] as String? ?? 'pending'},
        ),
      AiActionToolNames.proposeRecordPayment => (
          ProposedActionKind.recordPayment,
          {if (args['amount'] != null) 'amount': (args['amount'] as num).toInt()},
        ),
      AiActionToolNames.proposeSetPrice => (
          ProposedActionKind.setPrice,
          {'value': (args['value'] as num?)?.toInt() ?? 0},
        ),
      AiActionToolNames.proposeSetDueDate => (
          ProposedActionKind.setDueDate,
          {'dueDate': args['dueDate'] as String? ?? ''},
        ),
      _ => (ProposedActionKind.setStatus, <String, dynamic>{}),
    };

    return ProposedAction(
      id: const Uuid().v4(),
      kind: kind,
      params: params,
      candidateOrderIds: orderIds,
    );
  }
}
