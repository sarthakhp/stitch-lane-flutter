import '../../../../backend/database/sqlite_database.dart';
import '../ai_query_result.dart';
import '../ai_query_sql.dart';

/// Order-centric lookups: get_orders, get_due_orders.
class OrderQueryHandler {
  OrderQueryHandler._();

  static const _selectColumns = '''
    SELECT o.id AS id, o.title, o.value, o.status, o.due_date,
           o.total_paid_amount, ${AiQuerySql.outstanding} AS outstanding,
           c.name AS customer_name, o.customer_id
    FROM orders o
    JOIN customers c ON c.id = o.customer_id
  ''';

  static Future<AiQueryResult> getOrders(Map<String, dynamic> args) async {
    final where = <String>[];

    final customerName = (args['customerName'] as String?)?.trim();
    if (customerName != null && customerName.isNotEmpty) {
      where.add(AiQuerySql.nameLike('c.name', customerName));
    }

    final status = (args['status'] as String?)?.trim();
    if (status != null && status.isNotEmpty) {
      where.add("o.status = '${AiQuerySql.literal(status)}'");
    }

    final dueBefore = (args['dueBefore'] as String?)?.trim();
    if (dueBefore != null && dueBefore.isNotEmpty) {
      where.add("o.due_date < '${AiQuerySql.literal(dueBefore)}'");
    }
    final dueAfter = (args['dueAfter'] as String?)?.trim();
    if (dueAfter != null && dueAfter.isNotEmpty) {
      where.add("o.due_date >= '${AiQuerySql.literal(dueAfter)}'");
    }

    final paidState = (args['paidState'] as String?)?.trim();
    if (paidState != null && paidState.isNotEmpty) {
      final clause = AiQuerySql.paidStateClause(paidState);
      if (clause != null) where.add(clause);
    }

    final sql = '''
      $_selectColumns
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY o.due_date ASC
      LIMIT ${AiQueryResult.defaultMaxRows + 1}
    ''';

    final rows = await SqliteDatabase.rawQuery(sql);
    return AiQueryResult.boundedRows(rows);
  }

  /// Orders due within [withinDays] from today. Excludes 'done'. By default
  /// also includes already-overdue orders (set includeOverdue=false to only
  /// look forward).
  static Future<AiQueryResult> getDueOrders(Map<String, dynamic> args) async {
    final withinDays = (args['withinDays'] as num?)?.toInt() ?? 3;
    final includeOverdue = args['includeOverdue'] != false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = today.add(Duration(days: withinDays));
    final todayStr = _isoDate(today);
    final untilStr = _isoDate(until.add(const Duration(days: 1)));

    final where = <String>[
      "o.status != 'done'",
      "o.due_date < '$untilStr'",
    ];
    if (!includeOverdue) where.add("o.due_date >= '$todayStr'");

    final sql = '''
      $_selectColumns
      WHERE ${where.join(' AND ')}
      ORDER BY o.due_date ASC
      LIMIT ${AiQueryResult.defaultMaxRows + 1}
    ''';

    final rows = await SqliteDatabase.rawQuery(sql);
    return AiQueryResult.boundedRows(
      rows,
      summary: {'today': todayStr, 'within_days': withinDays},
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
