import 'dart:convert';

/// Shared codec for the "list of linked audio recordings" stored on
/// [Measurement] and [Order].
///
/// Both the domain JSON (`audioFilePaths`) and the SQLite column
/// (`audio_file_paths`, a JSON-encoded array) read through [read], which also
/// accepts a legacy single-path value (`audioFilePath` / `audio_file_path`)
/// so pre-feature rows and old backups migrate in as a one-element list with
/// no data migration step.
class AudioPathList {
  AudioPathList._();

  /// Resolve a path list from a primary value (a `List`, or a JSON-encoded
  /// array string) and an optional [legacySingle] fallback. Blank entries are
  /// dropped. Never throws — malformed input yields an empty list.
  static List<String> read(Object? primary, {Object? legacySingle}) {
    final fromPrimary = _coerce(primary);
    if (fromPrimary.isNotEmpty) return fromPrimary;

    if (legacySingle is String && legacySingle.trim().isNotEmpty) {
      return [legacySingle];
    }
    return const [];
  }

  static List<String> _coerce(Object? value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {
        // Not JSON — treat the whole string as a single path.
        return [value];
      }
    }
    return const [];
  }

  /// Encode for the SQLite `audio_file_paths` column. Always valid JSON.
  static String encode(List<String> paths) => jsonEncode(paths);
}
