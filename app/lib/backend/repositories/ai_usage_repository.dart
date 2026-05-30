import 'package:sqflite/sqflite.dart';
import '../database/sqlite_database.dart';
import '../../domain/services/ai_gateway/usage_event.dart';

/// SQLite-backed DAO for `ai_usage_events`.
///
/// Writes are best-effort (callers should not block user-visible flows on
/// usage persistence — the gateway wraps inserts in try/catch). Reads back
/// individual events for the dashboard and aggregate rollups.
class AiUsageRepository {
  static Future<Database> get _db => SqliteDatabase.database;

  /// Inserts one event. Returns true on success.
  Future<bool> insert(UsageEvent event) async {
    final db = await _db;
    await db.insert(
      'ai_usage_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  /// Range query, newest first. Optional filters narrow by caller and/or
  /// provider. [limit] caps the result count (default 500).
  Future<List<UsageEvent>> queryRange({
    required DateTime from,
    required DateTime to,
    String? callerTag,
    UsageProvider? provider,
    int limit = 500,
  }) async {
    final db = await _db;
    final where = <String>[
      'occurred_at >= ?',
      'occurred_at <= ?',
    ];
    final args = <Object?>[
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    ];
    if (callerTag != null) {
      where.add('caller_tag = ?');
      args.add(callerTag);
    }
    if (provider != null) {
      where.add('provider = ?');
      args.add(provider.name);
    }
    final rows = await db.query(
      'ai_usage_events',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(UsageEvent.fromMap).toList(growable: false);
  }

  /// Returns a single rolled-up summary for the given range and optional
  /// filters. Computed via SQL aggregation rather than client-side reduce, so
  /// this scales fine when the table grows.
  Future<UsageSummary> summarize({
    required DateTime from,
    required DateTime to,
    String? callerTag,
    UsageProvider? provider,
  }) async {
    final db = await _db;
    final where = <String>[
      'occurred_at >= ?',
      'occurred_at <= ?',
    ];
    final args = <Object?>[
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    ];
    if (callerTag != null) {
      where.add('caller_tag = ?');
      args.add(callerTag);
    }
    if (provider != null) {
      where.add('provider = ?');
      args.add(provider.name);
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total_events,
        COALESCE(SUM(input_tokens), 0)        AS total_input_tokens,
        COALESCE(SUM(output_tokens), 0)       AS total_output_tokens,
        COALESCE(SUM(audio_input_ms), 0)      AS total_audio_input_ms,
        COALESCE(SUM(audio_output_ms), 0)     AS total_audio_output_ms,
        COALESCE(SUM(input_chars), 0)         AS total_input_chars,
        COALESCE(SUM(estimated_cost_usd), 0)  AS total_cost,
        SUM(CASE WHEN estimated_cost_usd IS NULL THEN 1 ELSE 0 END)
                                              AS events_missing_cost
      FROM ai_usage_events
      WHERE ${where.join(' AND ')}
      ''',
      args,
    );

    if (rows.isEmpty) return UsageSummary.zero;
    final r = rows.first;
    return UsageSummary(
      totalEvents: (r['total_events'] as int?) ?? 0,
      totalInputTokens: (r['total_input_tokens'] as int?) ?? 0,
      totalOutputTokens: (r['total_output_tokens'] as int?) ?? 0,
      totalAudioInputMs: (r['total_audio_input_ms'] as int?) ?? 0,
      totalAudioOutputMs: (r['total_audio_output_ms'] as int?) ?? 0,
      totalInputChars: (r['total_input_chars'] as int?) ?? 0,
      totalEstimatedCostUsd: ((r['total_cost'] as num?) ?? 0).toDouble(),
      eventsMissingCost: (r['events_missing_cost'] as int?) ?? 0,
    );
  }

  /// Group by caller_tag for the dashboard's "by feature" breakdown.
  Future<Map<String, UsageSummary>> summarizeByCallerTag({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        caller_tag,
        COUNT(*) AS total_events,
        COALESCE(SUM(input_tokens), 0)        AS total_input_tokens,
        COALESCE(SUM(output_tokens), 0)       AS total_output_tokens,
        COALESCE(SUM(audio_input_ms), 0)      AS total_audio_input_ms,
        COALESCE(SUM(audio_output_ms), 0)     AS total_audio_output_ms,
        COALESCE(SUM(input_chars), 0)         AS total_input_chars,
        COALESCE(SUM(estimated_cost_usd), 0)  AS total_cost,
        SUM(CASE WHEN estimated_cost_usd IS NULL THEN 1 ELSE 0 END)
                                              AS events_missing_cost
      FROM ai_usage_events
      WHERE occurred_at >= ? AND occurred_at <= ?
      GROUP BY caller_tag
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return {
      for (final r in rows)
        (r['caller_tag'] as String): UsageSummary(
          totalEvents: (r['total_events'] as int?) ?? 0,
          totalInputTokens: (r['total_input_tokens'] as int?) ?? 0,
          totalOutputTokens: (r['total_output_tokens'] as int?) ?? 0,
          totalAudioInputMs: (r['total_audio_input_ms'] as int?) ?? 0,
          totalAudioOutputMs: (r['total_audio_output_ms'] as int?) ?? 0,
          totalInputChars: (r['total_input_chars'] as int?) ?? 0,
          totalEstimatedCostUsd:
              ((r['total_cost'] as num?) ?? 0).toDouble(),
          eventsMissingCost: (r['events_missing_cost'] as int?) ?? 0,
        ),
    };
  }

  /// Delete rows older than [cutoff]. Useful if you ever want auto-pruning,
  /// not called from anywhere yet.
  Future<int> deleteBefore(DateTime cutoff) async {
    final db = await _db;
    return db.delete(
      'ai_usage_events',
      where: 'occurred_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
