/// Single source of truth for the SQL expressions that encode business rules
/// (paid status, outstanding amount). Every typed handler builds its queries
/// from these so the rules are defined exactly once. All fragments assume the
/// orders table is aliased as `o`.
class AiQuerySql {
  AiQuerySql._();

  /// Fully paid: a real price is set and payments cover it.
  static const String fullyPaid =
      '(o.value IS NOT NULL AND o.value > 0 AND o.total_paid_amount >= o.value)';

  /// Remaining amount owed (0 when fully paid or price not set).
  static const String outstanding =
      'CASE WHEN o.value IS NOT NULL AND o.value > o.total_paid_amount '
      'THEN o.value - o.total_paid_amount ELSE 0 END';

  /// Maps a paidState filter token to a WHERE predicate. Returns null for an
  /// unknown token (caller should ignore the filter).
  static String? paidStateClause(String state) {
    switch (state) {
      case 'paid':
        return fullyPaid;
      case 'unpaid':
        return 'o.value IS NOT NULL AND o.total_paid_amount = 0';
      case 'partial':
        return 'o.total_paid_amount > 0 AND NOT $fullyPaid';
      case 'price_not_set':
        return 'o.value IS NULL';
      default:
        return null;
    }
  }

  /// Escapes a user/LLM-supplied string for safe embedding in a single-quoted
  /// SQL literal. Typed handlers build SQL by string composition (not bound
  /// params) so values must be escaped here.
  static String literal(String raw) => raw.replaceAll("'", "''");

  /// Case-insensitive substring match on customer name, OR-combining scripts
  /// when the term carries both (e.g. "Ramesh (રમેશ)").
  static String nameLike(String column, String term) {
    final cleaned = term.trim();
    final parts = RegExp(r'[()]+')
        .allMatches(cleaned)
        .isNotEmpty
        ? cleaned.split(RegExp(r'[()]+'))
        : [cleaned];
    final clauses = parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => "LOWER($column) LIKE LOWER('%${literal(p)}%')")
        .toList();
    if (clauses.isEmpty) return '1=1';
    return '(${clauses.join(' OR ')})';
  }
}
