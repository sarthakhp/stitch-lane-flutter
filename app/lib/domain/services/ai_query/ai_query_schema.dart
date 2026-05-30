/// Schema + business-rule reference handed to the model for the run_sql
/// escape hatch. The typed tools encode these rules themselves; this text is
/// the fallback contract for when the model writes raw SQL.
class AiQuerySchema {
  AiQuerySchema._();

  static const String description = '''
DATABASE (SQLite, all dates ISO8601 strings, booleans 0/1):
- customers(id PK, name, phone_number, description, created)
- orders(id PK, customer_id FK, title, due_date, description, created,
    status TEXT[pending/ready/done], value INT rupees NULLABLE,
    is_paid INT 0/1, total_paid_amount INT rupees,
    payments TEXT JSON [{"id","date","amount"}], image_paths TEXT JSON, payment_date)
- measurements(id PK, customer_id FK, description, created, modified, audio_file_path)

BUSINESS RULES (authoritative — use these, do not guess):
- value IS NULL  => "price not decided". Exclude such orders from revenue /
  outstanding sums. value = 0 is a real zero price, NOT "undecided".
- Fully paid:   value IS NOT NULL AND value > 0 AND total_paid_amount >= value
- Outstanding:  CASE WHEN value IS NOT NULL AND value > total_paid_amount
                THEN value - total_paid_amount ELSE 0 END
- Do NOT trust the is_paid column for logic; recompute with the rule above.
- status: pending = in progress, ready = ready for the customer to collect,
  done = collected/delivered.
- Earnings by date use the payments JSON, NOT total_paid_amount:
    SELECT SUM(CAST(je.value ->> 'amount' AS INTEGER))
    FROM orders o, json_each(o.payments) je
    WHERE je.value ->> 'date' >= 'YYYY-MM-DD' AND je.value ->> 'date' < 'YYYY-MM-DD'
- Names: always LOWER(name) LIKE LOWER('%term%'), never exact match.''';
}
