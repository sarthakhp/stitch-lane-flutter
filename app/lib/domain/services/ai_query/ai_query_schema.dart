/// Schema + business-rule reference handed to the model for the run_sql
/// escape hatch. The typed tools encode these rules themselves; this text is
/// the fallback contract for when the model writes raw SQL.
class AiQuerySchema {
  AiQuerySchema._();

  static const String description = '''
TABLES (SQLite; dates ISO8601; bools 0/1):
- customers(id, name, phone_number, description, created)
- orders(id, customer_id, title, due_date, description, created,
    status[pending/ready/done], value INT rupees NULL=undecided,
    is_paid 0/1, total_paid_amount INT, payments JSON[{id,date,amount}],
    image_paths JSON, payment_date)
- measurements(id, customer_id, description, created, modified, audio_file_path)

SQL RULES (authoritative):
- value NULL = price undecided → exclude from revenue/outstanding; value 0 is a real price.
- Outstanding = CASE WHEN value IS NOT NULL AND value>total_paid_amount THEN value-total_paid_amount ELSE 0 END.
  Fully paid = value>0 AND total_paid_amount>=value. Recompute — do not trust is_paid.
- Earnings by date use payments JSON, not total_paid_amount:
    SUM(CAST(je.value->>'amount' AS INTEGER)) FROM orders o, json_each(o.payments) je
    WHERE je.value->>'date' >= 'FROM' AND je.value->>'date' < 'TO'.
- Names: LOWER(name) LIKE LOWER('%term%'), never exact match.''';
}
