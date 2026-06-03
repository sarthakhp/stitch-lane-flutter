import 'package:langchain/langchain.dart';

/// Names of the write-side `propose_*` tools — shared by the specs (sent to the
/// model) and the factory (builds the staged action). Constants so they can't
/// drift.
class AiActionToolNames {
  AiActionToolNames._();

  static const proposeSetStatus = 'propose_set_status';
  static const proposeRecordPayment = 'propose_record_payment';
  static const proposeSetPrice = 'propose_set_price';
  static const proposeSetDueDate = 'propose_set_due_date';

  static const all = {
    proposeSetStatus,
    proposeRecordPayment,
    proposeSetPrice,
    proposeSetDueDate,
  };
}

/// Shared `orderIds` schema: one id when the model is sure, several when it
/// cannot decide (the user then picks which order the change applies to).
const Map<String, dynamic> _orderIdsSchema = {
  'type': 'array',
  'items': {'type': 'string'},
  'description':
      'Order id(s) the change may apply to. Pass exactly one when certain; '
      'pass every plausible match when unsure so the user can pick.',
};

/// Write tools exposed to the chat model. These NEVER mutate data — each one
/// only stages a change for the user to confirm with a tap.
const List<ToolSpec> aiActionToolSpecs = [
  ToolSpec(
    name: AiActionToolNames.proposeSetStatus,
    description:
        'Propose changing an order\'s status. Stages the change for the user '
        'to confirm — it is NOT applied until they tap Confirm.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'orderIds': _orderIdsSchema,
        'status': {
          'type': 'string',
          'enum': ['pending', 'ready', 'done'],
        },
      },
      'required': ['orderIds', 'status'],
    },
  ),
  ToolSpec(
    name: AiActionToolNames.proposeRecordPayment,
    description:
        'Propose recording a payment against an order. Omit amount to pay the '
        'full remaining balance. Stages the change for the user to confirm.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'orderIds': _orderIdsSchema,
        'amount': {
          'type': 'integer',
          'description':
              'Payment amount in rupees. Omit to pay the full remaining.',
        },
      },
      'required': ['orderIds'],
    },
  ),
  ToolSpec(
    name: AiActionToolNames.proposeSetPrice,
    description:
        'Propose setting an order\'s price (rupees), e.g. for orders with no '
        'price set yet. Stages the change for the user to confirm.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'orderIds': _orderIdsSchema,
        'value': {'type': 'integer', 'description': 'Price in rupees.'},
      },
      'required': ['orderIds', 'value'],
    },
  ),
  ToolSpec(
    name: AiActionToolNames.proposeSetDueDate,
    description:
        'Propose changing an order\'s due date. Resolve relative phrases '
        '("next Friday") to an absolute date yourself. Stages the change for '
        'the user to confirm.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'orderIds': _orderIdsSchema,
        'dueDate': {
          'type': 'string',
          'description': 'Absolute due date, ISO format YYYY-MM-DD.',
        },
      },
      'required': ['orderIds', 'dueDate'],
    },
  ),
];
