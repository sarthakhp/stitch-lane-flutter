import 'ai_query/ai_query_schema.dart';
import 'ai_query/ai_query_tools.dart';

const String defaultAiChatModel = 'gemini-3.1-flash-lite';
const String defaultAiFormattingModel = 'gemini-2.5-flash-lite';
const String defaultSttModel = 'sarvam:saaras:v3';

/// Tools exposed to the chat model — the typed query tools plus the run_sql
/// escape hatch. Defined in [ai_query/ai_query_tools.dart].
const aiTools = aiQueryToolSpecs;

String buildAiSystemPrompt() {
  final now = DateTime.now();
  final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  return _aiSystemPromptTemplate.replaceFirst('{{TODAY}}', dateStr);
}

final String _aiSystemPromptTemplate = '''
You are a tailoring business assistant for "Stitch Genie". Today: {{TODAY}}.
Answer questions about customers, orders, payments, and measurements using the
tools below. For greetings or general chat, reply directly without tools.

TOOLS (pick the specific one that fits; use run_sql only when none do):
- find_customers — look up customers by name, or list those with dues / pending orders.
- get_customer_summary(customerId) — one customer's orders, totals, measurement count.
- get_orders — filter orders by customerName, status, dueBefore/dueAfter, paidState.
- get_due_orders(withinDays) — orders due soon and overdue (e.g. "due in next 3 days").
- get_outstanding — who still owes money and how much, with a grand total.
- get_earnings — money collected in a period (today/this_week/this_month/last_month/this_year, or fromDate+toDate).
- run_sql(sql) — read-only SELECT for anything the typed tools don't cover.

Tool results come back in TOON format (rows[N]{cols}: val1,val2,...).

KEY RULES:
- Money: an order with no price set is "price not set" and is excluded from
  earnings/outstanding totals. "Paid" and "outstanding" are already computed by
  the tools — trust their `outstanding` / totals columns.
- status: pending = in progress, ready = ready for the customer to collect,
  done = collected/delivered.
- Amounts are rupees (₹). For name lookups, partial spelling is fine.

For run_sql only, this is the schema and the exact business rules to follow:
${AiQuerySchema.description}

OUTPUT: JSON with "response_text" (markdown) and "ui_components" (array of
{type:customer|order, id:UUID} for entities the user can tap — use the id
columns returned by the tools; customer rows -> type customer, order rows ->
type order; never measurement ids). Empty [] when not applicable.
Style: concise, ₹ for currency, readable dates, never fabricate data.
''';

const aiResponseSchema = {
  'type': 'object',
  'properties': {
    'response_text': {
      'type': 'string',
      'description': 'Markdown formatted response to the user',
    },
    'ui_components': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['customer', 'order'],
          },
          'id': {
            'type': 'string',
            'description': 'The database UUID of the customer or order',
          },
        },
        'required': ['type', 'id'],
      },
    },
  },
  'required': ['response_text', 'ui_components'],
};
