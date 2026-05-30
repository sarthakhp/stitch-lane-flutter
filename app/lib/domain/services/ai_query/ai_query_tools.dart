import 'package:langchain/langchain.dart';

/// Tool names — shared by the specs (sent to the model) and the dispatcher
/// (routes calls). Constants so the two can't drift.
class AiQueryToolNames {
  AiQueryToolNames._();
  static const findCustomers = 'find_customers';
  static const getCustomerSummary = 'get_customer_summary';
  static const getOrders = 'get_orders';
  static const getDueOrders = 'get_due_orders';
  static const getOutstanding = 'get_outstanding';
  static const getEarnings = 'get_earnings';
  static const runSql = 'run_sql';
}

/// The tool surface exposed to the chat model. Typed tools cover the common
/// questions reliably; run_sql is the escape hatch for everything else.
const List<ToolSpec> aiQueryToolSpecs = [
  ToolSpec(
    name: AiQueryToolNames.findCustomers,
    description:
        'Find customers by name, or list customers who have outstanding dues '
        'or pending orders. Returns each customer with order_count, '
        'pending_count and outstanding (₹).',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'nameLike': {
          'type': 'string',
          'description': 'Partial name to search (case-insensitive).',
        },
        'withOutstanding': {
          'type': 'boolean',
          'description': 'Only customers who still owe money.',
        },
        'withPendingOrders': {
          'type': 'boolean',
          'description': 'Only customers with at least one pending order.',
        },
      },
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.getCustomerSummary,
    description:
        'Full picture of one customer: their orders (with outstanding), totals '
        '(order_count, total_outstanding, pending_count) and measurement_count. '
        'Use after find_customers to get the customer id.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'customerId': {'type': 'string'},
      },
      'required': ['customerId'],
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.getOrders,
    description:
        'List orders with optional filters. Each row has customer_name, value, '
        'status, due_date, total_paid_amount and outstanding.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'customerName': {'type': 'string'},
        'status': {
          'type': 'string',
          'enum': ['pending', 'ready', 'done'],
        },
        'dueBefore': {'type': 'string', 'description': 'ISO date YYYY-MM-DD.'},
        'dueAfter': {'type': 'string', 'description': 'ISO date YYYY-MM-DD.'},
        'paidState': {
          'type': 'string',
          'enum': ['paid', 'unpaid', 'partial', 'price_not_set'],
        },
      },
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.getDueOrders,
    description:
        'Orders due within N days (and overdue by default). Excludes collected '
        '(done) orders. Use for "due in next 3 days", "overdue", etc.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'withinDays': {
          'type': 'integer',
          'description': 'Days from today. Default 3.',
        },
        'includeOverdue': {
          'type': 'boolean',
          'description': 'Include already-overdue orders. Default true.',
        },
      },
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.getOutstanding,
    description:
        'Who still owes money and how much. Returns customers with their '
        'outstanding (₹) plus a grand total. Optionally filter to one customer.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'customerName': {'type': 'string'},
      },
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.getEarnings,
    description:
        'Total money collected (from payments) in a period. Use a preset '
        'period OR an explicit fromDate+toDate.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': ['today', 'this_week', 'this_month', 'last_month', 'this_year'],
        },
        'fromDate': {'type': 'string', 'description': 'ISO date YYYY-MM-DD.'},
        'toDate': {'type': 'string', 'description': 'ISO date YYYY-MM-DD (inclusive).'},
      },
    },
  ),
  ToolSpec(
    name: AiQueryToolNames.runSql,
    description:
        'Escape hatch: run a read-only SQL SELECT for questions the other '
        'tools do not cover. Prefer the typed tools when one fits.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'sql': {'type': 'string', 'description': 'A SQL SELECT query.'},
      },
      'required': ['sql'],
    },
  ),
];
