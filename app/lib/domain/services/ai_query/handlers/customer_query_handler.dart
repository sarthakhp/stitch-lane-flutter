import '../../../../backend/database/sqlite_database.dart';
import '../ai_query_result.dart';
import '../ai_query_sql.dart';

/// Customer-centric lookups: find_customers, get_customer_summary.
class CustomerQueryHandler {
  CustomerQueryHandler._();

  static Future<AiQueryResult> findCustomers(Map<String, dynamic> args) async {
    final nameLike = (args['nameLike'] as String?)?.trim();
    final withOutstanding = args['withOutstanding'] == true;
    final withPendingOrders = args['withPendingOrders'] == true;

    final where = <String>[];
    if (nameLike != null && nameLike.isNotEmpty) {
      where.add(AiQuerySql.nameLike('c.name', nameLike));
    }

    final having = <String>[];
    if (withOutstanding) having.add('outstanding > 0');
    if (withPendingOrders) having.add('pending_count > 0');

    final sql = '''
      SELECT c.id AS id, c.name, c.phone_number,
             COUNT(o.id) AS order_count,
             SUM(CASE WHEN o.status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
             COALESCE(SUM(${AiQuerySql.outstanding}), 0) AS outstanding
      FROM customers c
      LEFT JOIN orders o ON o.customer_id = c.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY c.id
      ${having.isEmpty ? '' : 'HAVING ${having.join(' AND ')}'}
      ORDER BY c.name
      LIMIT ${AiQueryResult.defaultMaxRows + 1}
    ''';

    final rows = await SqliteDatabase.rawQuery(sql);
    return AiQueryResult.boundedRows(rows);
  }

  static Future<AiQueryResult> getCustomerSummary(
      Map<String, dynamic> args) async {
    final id = (args['customerId'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      return AiQueryResult.failure('customerId is required.');
    }
    final safeId = AiQuerySql.literal(id);

    final customerRows = await SqliteDatabase.rawQuery(
      "SELECT id, name, phone_number, description FROM customers WHERE id = '$safeId' LIMIT 1",
    );
    if (customerRows.isEmpty) {
      return AiQueryResult.failure('No customer found with that id.');
    }

    final orderRows = await SqliteDatabase.rawQuery('''
      SELECT o.id AS id, o.title, o.value, o.status, o.due_date,
             o.total_paid_amount, ${AiQuerySql.outstanding} AS outstanding
      FROM orders o
      WHERE o.customer_id = '$safeId'
      ORDER BY o.due_date DESC
      LIMIT ${AiQueryResult.defaultMaxRows}
    ''');

    final totals = await SqliteDatabase.rawQuery('''
      SELECT COUNT(*) AS order_count,
             COALESCE(SUM(${AiQuerySql.outstanding}), 0) AS total_outstanding,
             SUM(CASE WHEN o.status = 'pending' THEN 1 ELSE 0 END) AS pending_count
      FROM orders o WHERE o.customer_id = '$safeId'
    ''');

    final measurementCount = await SqliteDatabase.rawQuery(
      "SELECT COUNT(*) AS measurement_count FROM measurements WHERE customer_id = '$safeId'",
    );

    return AiQueryResult.boundedRows(
      orderRows,
      summary: {
        'customer': customerRows.first,
        'totals': {
          ...totals.first,
          ...measurementCount.first,
        },
      },
    );
  }
}
