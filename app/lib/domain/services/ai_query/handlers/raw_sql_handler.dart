import '../../../../backend/database/sqlite_database.dart';
import '../ai_query_result.dart';

/// Escape hatch for the long tail of questions the typed tools don't cover.
/// Read-only: SELECT statements only, dangerous keywords blocked, auto-limited.
class RawSqlHandler {
  RawSqlHandler._();

  static const _blocked = [
    'INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER',
    'CREATE', 'ATTACH', 'DETACH', 'PRAGMA',
  ];

  static Future<AiQueryResult> run(Map<String, dynamic> args) async {
    final sql = (args['sql'] as String?)?.trim() ?? '';
    if (sql.isEmpty) return AiQueryResult.failure('sql is required.');

    final upper = sql.toUpperCase();
    if (!upper.startsWith('SELECT')) {
      return AiQueryResult.failure('Only SELECT queries are allowed.');
    }
    for (final keyword in _blocked) {
      if (RegExp('\\b$keyword\\b').hasMatch(upper)) {
        return AiQueryResult.failure('$keyword is not allowed in read queries.');
      }
    }

    const limit = AiQueryResult.defaultMaxRows;
    final clean = sql.endsWith(';') ? sql.substring(0, sql.length - 1) : sql;
    final limited = upper.contains('LIMIT') ? clean : '$clean LIMIT ${limit + 1}';

    try {
      final rows = await SqliteDatabase.rawQuery(limited);
      if (rows.isEmpty && _usesExactNameMatch(sql)) {
        return AiQueryResult.failure(
          'No results. The query uses exact name match (= \'...\'), which '
          'misses spacing/casing differences. Retry with '
          "WHERE LOWER(name) LIKE LOWER('%term%').",
        );
      }
      return AiQueryResult.boundedRows(rows, maxRows: limit);
    } catch (e) {
      return AiQueryResult.failure('Query failed: $e');
    }
  }

  static bool _usesExactNameMatch(String sql) {
    if (!sql.toUpperCase().contains('NAME')) return false;
    return RegExp(r"""name\s*=\s*'[^']*'""", caseSensitive: false).hasMatch(sql);
  }
}
