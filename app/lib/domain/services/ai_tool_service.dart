import 'dart:convert';
import '../../backend/database/sqlite_database.dart';

const int _defaultMaxRows = 50;

/// Max response size in characters (~tokens). 8000 chars ≈ 2000 tokens.
const int _maxResponseSize = 6000;

class AiToolResult {
  final bool success;
  final List<Map<String, dynamic>>? rows;
  final int? totalRows;
  final bool? truncated;
  final String? error;

  AiToolResult._({
    required this.success,
    this.rows,
    this.totalRows,
    this.truncated,
    this.error,
  });

  factory AiToolResult.success(List<Map<String, dynamic>> rows, {bool truncated = false}) =>
      AiToolResult._(success: true, rows: rows, totalRows: rows.length, truncated: truncated);

  factory AiToolResult.error(String error) =>
      AiToolResult._(success: false, error: error);

  Map<String, dynamic> toJson() {
    if (!success) return {'error': error};
    return {
      'rows': rows,
      'totalRows': totalRows,
      if (truncated == true) 'truncated': true,
    };
  }
}

class AiToolService {
  static const String schemaDescription = '''
Tables:
- customers(id TEXT PK, name TEXT, phone_number TEXT, description TEXT, created TEXT)
- orders(id TEXT PK, customer_id TEXT FK→customers, title TEXT, due_date TEXT, description TEXT, created TEXT, status TEXT[pending/ready/done], value INT rupees, is_paid INT 0/1, total_paid_amount INT rupees, payments TEXT JSON, image_paths TEXT JSON, payment_date TEXT)
- measurements(id TEXT PK, customer_id TEXT FK→customers, description TEXT, created TEXT, modified TEXT, audio_file_path TEXT)
All dates are ISO8601 strings. Booleans are 0/1. payments is a JSON array: [{"id","date","amount"}]. Use json_each(payments) to query by payment date.''';

  /// Execute a read-only SQL query. Only SELECT statements are allowed.
  static Future<AiToolResult> queryDatabase(String sql, {int? maxRows}) async {
    final trimmed = sql.trim();

    // Only allow SELECT statements
    if (!trimmed.toUpperCase().startsWith('SELECT')) {
      return AiToolResult.error('Only SELECT queries are allowed.');
    }

    // Block dangerous keywords
    final upper = trimmed.toUpperCase();
    const blocked = ['INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE', 'ATTACH', 'DETACH', 'PRAGMA'];
    for (final keyword in blocked) {
      // Check for keyword as a separate word (not part of a column name)
      if (RegExp('\\b$keyword\\b').hasMatch(upper)) {
        return AiToolResult.error('$keyword statements are not allowed in read queries.');
      }
    }

    final limit = maxRows ?? _defaultMaxRows;

    // Add LIMIT if the query doesn't already have one
    if (!upper.contains('LIMIT')) {
      // Remove trailing semicolon if present
      final cleanSql = trimmed.endsWith(';') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
      final limitedSql = '$cleanSql LIMIT ${limit + 1}';
      return _executeQuery(limitedSql, limit);
    }

    return _executeQuery(trimmed, limit);
  }

  static Future<AiToolResult> _executeQuery(String sql, int limit) async {
    try {
      final results = await SqliteDatabase.rawQuery(sql);

      final truncated = results.length > limit;
      final rows = truncated ? results.sublist(0, limit) : results;

      // Check response size before returning
      final resultJson = jsonEncode(rows);
      if (resultJson.length > _maxResponseSize) {
        return AiToolResult.error(
          'Response too large (${rows.length} rows, ${resultJson.length} chars). '
          'Please write a more specific query: use SELECT with fewer columns, '
          'add WHERE filters, or use a smaller LIMIT.',
        );
      }

      // Hint if zero results and query uses exact name match
      if (rows.isEmpty && _usesExactNameMatch(sql)) {
        return AiToolResult.error(
          'No results found. The query uses exact name match (= \'...\') which '
          'may miss names with different spacing or casing. '
          'Retry using: WHERE LOWER(name) LIKE LOWER(\'%search_term%\')',
        );
      }

      return AiToolResult.success(rows, truncated: truncated);
    } catch (e) {
      return AiToolResult.error('Query failed: $e');
    }
  }

  /// Detects if the SQL uses exact match (= '...') on a name column.
  static bool _usesExactNameMatch(String sql) {
    final upper = sql.toUpperCase();
    if (!upper.contains('NAME')) return false;
    // Matches patterns like: name = 'something' or name='something'
    return RegExp(r"""name\s*=\s*'[^']*'""", caseSensitive: false).hasMatch(sql);
  }
}
