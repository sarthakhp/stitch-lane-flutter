import 'dart:convert';

/// Result of any AI query tool (typed or raw SQL). Carries either rows + an
/// optional summary map, or an error. [toJson] is what gets serialized back
/// to the model (TOON-encoded by the executor).
class AiQueryResult {
  final bool success;
  final List<Map<String, dynamic>>? rows;
  final int? totalRows;
  final bool truncated;

  /// Extra top-level fields merged into [toJson] — e.g. totals, the resolved
  /// date range, a customer header for a summary. Keeps a single result shape
  /// while letting each handler attach what's relevant.
  final Map<String, dynamic>? summary;

  final String? error;

  AiQueryResult._({
    required this.success,
    this.rows,
    this.totalRows,
    this.truncated = false,
    this.summary,
    this.error,
  });

  factory AiQueryResult.rows(
    List<Map<String, dynamic>> rows, {
    bool truncated = false,
    Map<String, dynamic>? summary,
  }) =>
      AiQueryResult._(
        success: true,
        rows: rows,
        totalRows: rows.length,
        truncated: truncated,
        summary: summary,
      );

  /// For aggregate-only answers (earnings total, outstanding total) where
  /// there are no per-row results worth returning.
  factory AiQueryResult.summaryOnly(Map<String, dynamic> summary) =>
      AiQueryResult._(success: true, summary: summary);

  factory AiQueryResult.failure(String error) =>
      AiQueryResult._(success: false, error: error);

  Map<String, dynamic> toJson() {
    if (!success) return {'error': error};
    return {
      if (rows != null) 'rows': rows,
      if (totalRows != null) 'totalRows': totalRows,
      if (truncated) 'truncated': true,
      ...?summary,
    };
  }

  /// Guards every handler against returning a payload too large for the model
  /// context. ~6000 chars ≈ 1500 tokens.
  static const int maxResponseChars = 6000;
  static const int defaultMaxRows = 50;

  /// Returns an error result if [rows] serialize beyond [maxResponseChars],
  /// otherwise a rows result. Shared by all handlers.
  static AiQueryResult boundedRows(
    List<Map<String, dynamic>> rows, {
    int maxRows = defaultMaxRows,
    Map<String, dynamic>? summary,
  }) {
    final truncated = rows.length > maxRows;
    final clipped = truncated ? rows.sublist(0, maxRows) : rows;
    final encoded = jsonEncode(clipped);
    if (encoded.length > maxResponseChars) {
      return AiQueryResult.failure(
        'Response too large (${clipped.length} rows). Narrow the request: '
        'add a customer name, a status, or a tighter date range.',
      );
    }
    return AiQueryResult.rows(clipped, truncated: truncated, summary: summary);
  }
}
