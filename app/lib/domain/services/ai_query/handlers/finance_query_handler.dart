import '../../../../backend/database/sqlite_database.dart';
import '../ai_query_result.dart';
import '../ai_query_sql.dart';

/// Money questions: get_outstanding (who owes / how much is left) and
/// get_earnings (how much was collected in a period).
class FinanceQueryHandler {
  FinanceQueryHandler._();

  static Future<AiQueryResult> getOutstanding(Map<String, dynamic> args) async {
    final customerName = (args['customerName'] as String?)?.trim();
    final hasName = customerName != null && customerName.isNotEmpty;
    final nameClause = hasName ? AiQuerySql.nameLike('c.name', customerName) : null;
    final rowsWhere = nameClause == null ? '' : 'WHERE $nameClause';

    final rows = await SqliteDatabase.rawQuery('''
      SELECT c.id AS id, c.name, c.phone_number,
             COALESCE(SUM(${AiQuerySql.outstanding}), 0) AS outstanding
      FROM customers c
      JOIN orders o ON o.customer_id = c.id
      $rowsWhere
      GROUP BY c.id
      HAVING outstanding > 0
      ORDER BY outstanding DESC
      LIMIT ${AiQueryResult.defaultMaxRows + 1}
    ''');

    // Grand total over the same (optionally name-filtered) open orders.
    final totalWhere = [
      if (nameClause != null) nameClause,
      '${AiQuerySql.outstanding} > 0',
    ].join(' AND ');
    final total = await SqliteDatabase.rawQuery('''
      SELECT COALESCE(SUM(${AiQuerySql.outstanding}), 0) AS total_outstanding,
             COUNT(*) AS open_orders
      FROM orders o
      JOIN customers c ON c.id = o.customer_id
      WHERE $totalWhere
    ''');

    return AiQueryResult.boundedRows(
      rows,
      summary: {'totals': total.first},
    );
  }

  static Future<AiQueryResult> getEarnings(Map<String, dynamic> args) async {
    final range = _resolveRange(args);
    if (range == null) {
      return AiQueryResult.failure(
        'Provide either "period" (today/this_week/this_month/last_month/this_year) '
        'or both "fromDate" and "toDate" as YYYY-MM-DD.',
      );
    }
    final (from, toExclusive) = range;

    final result = await SqliteDatabase.rawQuery('''
      SELECT COALESCE(SUM(CAST(je.value ->> 'amount' AS INTEGER)), 0) AS total_earned,
             COUNT(*) AS payment_count
      FROM orders o, json_each(o.payments) je
      WHERE je.value ->> 'date' >= '$from'
        AND je.value ->> 'date' < '$toExclusive'
    ''');

    return AiQueryResult.summaryOnly({
      'period': {'from': from, 'to_exclusive': toExclusive},
      'earnings': result.first,
    });
  }

  /// Resolves the requested period to [from, toExclusive) ISO dates, or null
  /// if neither a known period nor an explicit range was given.
  static (String, String)? _resolveRange(Map<String, dynamic> args) {
    final fromDate = (args['fromDate'] as String?)?.trim();
    final toDate = (args['toDate'] as String?)?.trim();
    if (fromDate != null &&
        fromDate.isNotEmpty &&
        toDate != null &&
        toDate.isNotEmpty) {
      final to = DateTime.tryParse(toDate);
      final toExclusive =
          to != null ? _iso(to.add(const Duration(days: 1))) : toDate;
      return (fromDate, toExclusive);
    }

    final period = (args['period'] as String?)?.trim();
    if (period == null || period.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'today':
        return (_iso(today), _iso(today.add(const Duration(days: 1))));
      case 'this_week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (_iso(monday), _iso(monday.add(const Duration(days: 7))));
      case 'this_month':
        return (
          _iso(DateTime(now.year, now.month, 1)),
          _iso(DateTime(now.year, now.month + 1, 1)),
        );
      case 'last_month':
        return (
          _iso(DateTime(now.year, now.month - 1, 1)),
          _iso(DateTime(now.year, now.month, 1)),
        );
      case 'this_year':
        return (
          _iso(DateTime(now.year, 1, 1)),
          _iso(DateTime(now.year + 1, 1, 1)),
        );
      default:
        return null;
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
