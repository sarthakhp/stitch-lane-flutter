import 'ai_query_result.dart';
import 'ai_query_tools.dart';
import 'handlers/customer_query_handler.dart';
import 'handlers/finance_query_handler.dart';
import 'handlers/order_query_handler.dart';
import 'handlers/raw_sql_handler.dart';

/// Routes a tool call (name + args) to its handler and returns an
/// [AiQueryResult]. Unknown names return a recoverable error so the model can
/// self-correct rather than crash the turn.
class AiQueryDispatcher {
  AiQueryDispatcher._();

  static bool isKnown(String name) => _handlers.containsKey(name);

  static Future<AiQueryResult> dispatch(
    String name,
    Map<String, dynamic> args,
  ) async {
    final handler = _handlers[name];
    if (handler == null) {
      return AiQueryResult.failure(
        '"$name" is not a valid tool. Available: ${_handlers.keys.join(', ')}.',
      );
    }
    return handler(args);
  }

  static final Map<String,
          Future<AiQueryResult> Function(Map<String, dynamic>)> _handlers = {
    AiQueryToolNames.findCustomers: CustomerQueryHandler.findCustomers,
    AiQueryToolNames.getCustomerSummary: CustomerQueryHandler.getCustomerSummary,
    AiQueryToolNames.getOrders: OrderQueryHandler.getOrders,
    AiQueryToolNames.getDueOrders: OrderQueryHandler.getDueOrders,
    AiQueryToolNames.getOutstanding: FinanceQueryHandler.getOutstanding,
    AiQueryToolNames.getEarnings: FinanceQueryHandler.getEarnings,
    AiQueryToolNames.runSql: RawSqlHandler.run,
  };
}
