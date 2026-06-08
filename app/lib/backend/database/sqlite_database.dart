import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqliteDatabase {
  static Database? _database;
  static const String _dbName = 'stitch_genie.db';

  /// Public filename of the live SQLite DB. Used by [DbSnapshotService] which
  /// reads / writes the file alongside this class on disk.
  static String get dbName => _dbName;
  static const int _dbVersion = 9;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT,
        description TEXT,
        created TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        title TEXT,
        due_date TEXT NOT NULL,
        description TEXT,
        created TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        value INTEGER,
        is_paid INTEGER NOT NULL DEFAULT 0,
        image_paths TEXT NOT NULL DEFAULT '[]',
        payment_date TEXT,
        payments TEXT NOT NULL DEFAULT '[]',
        total_paid_amount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_orders_customer_id ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_due_date ON orders(due_date)');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        description TEXT NOT NULL,
        created TEXT NOT NULL,
        modified TEXT NOT NULL,
        audio_file_path TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_measurements_customer_id ON measurements(customer_id)');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        due_date_warning_threshold INTEGER NOT NULL DEFAULT 3,
        pending_orders_reminder_enabled INTEGER NOT NULL DEFAULT 0,
        pending_orders_reminder_time TEXT NOT NULL DEFAULT '08:30',
        auto_backup_enabled INTEGER NOT NULL DEFAULT 0,
        auto_backup_time TEXT NOT NULL DEFAULT '03:00',
        last_backup_time TEXT,
        debug_logs_enabled INTEGER NOT NULL DEFAULT 1,
        ai_chat_model TEXT,
        ai_formatting_model TEXT,
        last_backup_status TEXT,
        last_backup_error TEXT,
        stt_model TEXT,
        tts_speaker TEXT
      )
    ''');

    await _createAiUsageEventsTable(db);
  }

  /// One row per external-AI network call. Written by the AiGateway via
  /// UsageRecorder. Read by the dashboard. See [UsageEvent] for the field
  /// mapping. Token vs. duration fields are mutually nullable depending on
  /// the call kind (chat → tokens; STT/TTS → audio_*_ms / input_chars).
  static Future<void> _createAiUsageEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ai_usage_events (
        id TEXT PRIMARY KEY,
        occurred_at INTEGER NOT NULL,
        caller_tag TEXT NOT NULL,
        run_id TEXT,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        kind TEXT NOT NULL,
        input_tokens INTEGER,
        output_tokens INTEGER,
        total_tokens INTEGER,
        audio_input_ms INTEGER,
        audio_output_ms INTEGER,
        input_chars INTEGER,
        duration_ms INTEGER NOT NULL,
        estimated_cost_usd REAL,
        error_code TEXT,
        meta TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ai_usage_occurred_at ON ai_usage_events(occurred_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_usage_caller_tag ON ai_usage_events(caller_tag)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_usage_run_id ON ai_usage_events(run_id)',
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE settings ADD COLUMN ai_chat_model TEXT');
      await db.execute('ALTER TABLE settings ADD COLUMN ai_voice_model TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE settings ADD COLUMN last_backup_status TEXT');
      await db.execute('ALTER TABLE settings ADD COLUMN last_backup_error TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE settings ADD COLUMN stt_provider TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE settings ADD COLUMN ai_formatting_model TEXT');
      await db.execute('ALTER TABLE settings ADD COLUMN stt_model TEXT');
      // Migrate old values into new columns
      await db.execute('UPDATE settings SET ai_formatting_model = ai_voice_model WHERE ai_voice_model IS NOT NULL');
      await db.execute("UPDATE settings SET stt_model = CASE WHEN stt_provider = 'sarvam' THEN 'sarvam:saaras:v3' ELSE 'gemini:' || COALESCE(ai_voice_model, 'gemini-2.5-flash-lite') END WHERE stt_provider IS NOT NULL");
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE settings ADD COLUMN tts_speaker TEXT');
    }
    if (oldVersion < 7) {
      // gemini-3.1-flash-lite-preview was shut down on 2026-05-25. Rewrite
      // any persisted user selection to the GA model (gemini-3.1-flash-lite).
      // Affects all three slots: chat agent, formatting LLM, and the Gemini
      // STT model (which is stored prefixed as "gemini:<model>").
      await db.execute(
        "UPDATE settings SET ai_chat_model = 'gemini-3.1-flash-lite' "
        "WHERE ai_chat_model = 'gemini-3.1-flash-lite-preview'",
      );
      await db.execute(
        "UPDATE settings SET ai_formatting_model = 'gemini-3.1-flash-lite' "
        "WHERE ai_formatting_model = 'gemini-3.1-flash-lite-preview'",
      );
      await db.execute(
        "UPDATE settings SET stt_model = 'gemini:gemini-3.1-flash-lite' "
        "WHERE stt_model = 'gemini:gemini-3.1-flash-lite-preview'",
      );
    }
    if (oldVersion < 8) {
      // AI usage / cost tracking — see [UsageEvent] and [AiUsageRepository].
      // Backfilling historical usage is not possible, so the dashboard will
      // simply start from this migration's run time.
      await _createAiUsageEventsTable(db);
    }
    if (oldVersion < 9) {
      // Make orders.value nullable so "price not decided" (NULL) is distinct
      // from a real ₹0. SQLite can't drop a NOT NULL constraint in place, so
      // rebuild the table. Nothing references orders via FK, so this is safe.
      await _migrateOrdersValueNullable(db);
    }
  }

  /// v9: rebuild `orders` with a nullable `value` column, preserving all rows.
  static Future<void> _migrateOrdersValueNullable(Database db) async {
    await db.execute('''
      CREATE TABLE orders_new (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        title TEXT,
        due_date TEXT NOT NULL,
        description TEXT,
        created TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        value INTEGER,
        is_paid INTEGER NOT NULL DEFAULT 0,
        image_paths TEXT NOT NULL DEFAULT '[]',
        payment_date TEXT,
        payments TEXT NOT NULL DEFAULT '[]',
        total_paid_amount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');
    await db.execute('''
      INSERT INTO orders_new
      SELECT id, customer_id, title, due_date, description, created, status,
             value, is_paid, image_paths, payment_date, payments, total_paid_amount
      FROM orders
    ''');
    await db.execute('DROP TABLE orders');
    await db.execute('ALTER TABLE orders_new RENAME TO orders');
    await db.execute('CREATE INDEX idx_orders_customer_id ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_due_date ON orders(due_date)');
  }

  /// For the AI assistant feature — execute arbitrary read-only SQL
  static Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  static Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> deleteDb() async {
    await close();
    final path = await databasePath;
    await deleteDatabase(path);
  }

  /// Runs [block] with foreign key constraints disabled.
  /// Used during migration and bulk restore operations where data may contain
  /// orphaned records from Hive (which had no FK enforcement).
  static Future<T> withForeignKeysDisabled<T>(Future<T> Function() block) async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      return await block();
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }
}
