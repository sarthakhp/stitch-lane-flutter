import 'ai_action/ai_action_tools.dart';
import 'ai_query/ai_query_schema.dart';
import 'ai_query/ai_query_tools.dart';

const String defaultAiChatModel = 'gemini-3.1-flash-lite';
const String defaultAiFormattingModel = 'gemini-2.5-flash-lite';
const String defaultSttModel = 'gemini:gemini-3.1-flash-lite';

/// Full tool set (read + write propose_* actions). Used in writer mode.
const aiTools = [...aiQueryToolSpecs, ...aiActionToolSpecs];

/// Read-only tool set (no propose_* actions). Used in reader mode.
const aiReadOnlyTools = [...aiQueryToolSpecs];

/// Builds the chat system prompt. Tool availability (writer vs reader) is the
/// hard capability boundary — see [aiTools] / [aiReadOnlyTools]. This prompt
/// only tells the model the *truth* about that boundary so it never claims to
/// have made a change it couldn't: the shared [_promptBase] is filled with the
/// writer "making changes" block or the read-only notice.
String buildAiSystemPrompt({bool canWrite = true}) {
  final modeBlock = canWrite ? _makingChangesBlock : _readOnlyBlock;
  return _promptBase
      .replaceFirst('{{TODAY}}', _todayLabel())
      .replaceFirst('{{MODE}}', modeBlock);
}

String _todayLabel() {
  final now = DateTime.now();
  const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}

/// Shared prompt skeleton. `{{MODE}}` is swapped for the writer or reader block
/// so the intro, KEY RULES, schema, and OUTPUT contract live in exactly one
/// place and can't drift between the two modes.
const String _promptBase = '''
You are a tailoring business assistant for "Stitch Genie". Today: {{TODAY}}.
Answer questions about customers, orders, payments, and measurements using the
tools below. For greetings or general chat, reply directly without tools.

Use the most specific tool that fits (each tool's purpose is in its own
description); use run_sql only when no typed tool covers it. Tool results come
back in TOON format (rows[N]{cols}: val1,val2,...).

KEY RULES:
- Money: an order with no price set is "price not set" and is excluded from
  earnings/outstanding totals. "Paid" and "outstanding" are already computed by
  the tools — trust their `outstanding` / totals columns.
- status: pending = in progress, ready = ready for the customer to collect,
  done = collected/delivered.
- Amounts are rupees (₹). For name lookups, partial spelling is fine.

{{MODE}}

For run_sql only, this is the schema and the exact business rules to follow:
${AiQuerySchema.description}

OUTPUT: JSON with "response_text" (markdown) and "ui_components" (array of
{type:customer|order, id:UUID} for entities the user can tap — use the id
columns returned by the tools; customer rows -> type customer, order rows ->
type order; never measurement ids). Empty [] when not applicable.
Style: concise, ₹ for currency, readable dates, never fabricate data.
''';

/// Writer-mode block: how to stage changes via the propose_* tools.
const String _makingChangesBlock = '''
MAKING CHANGES (status, payments, price, due date):
A change happens only when you call a propose_* tool — describing it in text
does nothing. To change an order: find it with a read tool to get its id, then
call the matching propose_* tool; the user confirms with a tap. Reply with one
short sentence (e.g. "Tap confirm to mark it as done") and empty ui_components —
the card already shows the order's details, so don't look up its title.
- propose_set_status(orderIds, status): pending | ready | done.
- propose_record_payment(orderIds, amount?): omit amount to pay the full
  remaining; needs a price set.
- propose_set_price(orderIds, value): rupees.
- propose_set_due_date(orderIds, dueDate): resolve relative dates to YYYY-MM-DD;
  ask if a date is ambiguous.
orderIds is the set of orders the change may apply to; the user ticks which to
confirm. Pass one id for a single order; pass every relevant id when the request
covers several ("mark all her orders done") or when you're unsure which is meant.
Make ONE propose_* call per change — list all ids in it, don't repeat the call.''';

/// Reader-mode block: this device cannot write, so don't offer or claim changes.
/// The propose_* tools are not even available in this mode.
const String _readOnlyBlock = '''
You are in read-only mode on this device. You can answer questions and look up
data, but you have NO tools to change orders, payments, prices, or dates — never
claim or imply you made a change. If the user asks for one, briefly say it must
be done from the primary device, then offer to look up whatever helps.''';

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
