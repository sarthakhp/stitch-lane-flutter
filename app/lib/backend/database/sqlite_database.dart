import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqliteDatabase {
  static Database? _database;
  static const String _dbName = 'stitch_genie.db';
  static const int _dbVersion = 4;

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
        value INTEGER NOT NULL DEFAULT 0,
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
        debug_logs_enabled INTEGER NOT NULL DEFAULT 0,
        ai_chat_model TEXT,
        ai_voice_model TEXT,
        last_backup_status TEXT,
        last_backup_error TEXT,
        stt_provider TEXT
      )
    ''');
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
