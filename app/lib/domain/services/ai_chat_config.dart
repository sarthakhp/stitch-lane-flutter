import 'package:langchain/langchain.dart';
import 'ai_tool_service.dart';

const String defaultAiChatModel = 'gemini-3.1-flash-lite-preview';
const String defaultAiVoiceModel = 'gemini-2.5-flash-lite';

String buildAiSystemPrompt() {
  final now = DateTime.now();
  final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  return _aiSystemPromptTemplate.replaceFirst('{{TODAY}}', dateStr);
}

const String _aiSystemPromptTemplate = '''
You are a tailoring business assistant for "Stitch Genie". Today: {{TODAY}}.
Use the queryDatabase tool ONLY when the question needs data. For greetings/general chat, respond directly.
Tool results use TOON format (tabular: rows[N]{cols}: val1,val2,...).

${AiToolService.schemaDescription}

SQL rules:
- Names: ALWAYS use LOWER(name) LIKE LOWER('%term%'), never exact match. If input has both scripts like "Ramesh (રમેશ)", search with OR: WHERE LOWER(name) LIKE '%ramesh%' OR LOWER(name) LIKE '%રમેશ%'. If 0 results, try shorter/phonetic variants (e.g. "Hittu" → also try "Hitu").
- Earnings by date: SELECT SUM(CAST(json_each.value->>'amount' AS INTEGER)) FROM orders, json_each(orders.payments) WHERE json_each.value->>'date' >= 'YYYY-MM-DD'. Do NOT use total_paid_amount for date-based queries.
- orders.status: pending/ready/done. orders.value and total_paid_amount are in rupees.

Response: JSON with "response_text" (markdown) and "ui_components" (array of {type:customer/order, id:UUID} for entities the user can tap). Use customers.id for customers, orders.id for orders — never measurement or other IDs. Empty [] when not applicable.
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

const aiTools = [
  ToolSpec(
    name: 'queryDatabase',
    description:
        'Execute a read-only SQL SELECT query on the business database. '
        'Returns rows in TOON format. Use this to answer any question about customers, orders, measurements, or business metrics.',
    inputJsonSchema: {
      'type': 'object',
      'properties': {
        'sql': {
          'type': 'string',
          'description': 'A SQL SELECT query to execute.',
        },
      },
      'required': ['sql'],
    },
  ),
];
