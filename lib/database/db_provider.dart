import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../services/diagnostic_service.dart';

class DBProvider {
  DBProvider._internal();
  static final DBProvider instance = DBProvider._internal();

  static const String _databaseName = 'dukan_space_inventory.db';
  static const int _databaseVersion = 3;

  static const String tableInventory = 'inventory';
  static const String tablePhoneModels = 'phone_models';

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onOpen: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA cache_size = 2000;');
          await db.execute('PRAGMA temp_store = MEMORY;');
        } catch (_) {}
        DiagnosticService.instance.logInfo('Database', 'Database opened at version $_databaseVersion');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        DiagnosticService.instance.logInfo('Database', 'Database tables created at version $version');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE $tableInventory ADD COLUMN model_name TEXT DEFAULT ''");
            await db.execute("CREATE INDEX IF NOT EXISTS idx_inventory_model ON $tableInventory (model_name)");
          } catch (_) {}
        }
        await _createTables(db);
        DiagnosticService.instance.logInfo('Database', 'Database upgraded from $oldVersion to $newVersion');
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Table 1: InventoryTable (General purpose inventory table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_name TEXT DEFAULT '',
        accessory_group_id TEXT DEFAULT '',
        item_type TEXT NOT NULL,
        shelf_no TEXT NOT NULL,
        box_no TEXT NOT NULL,
        stock_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index on model_name for fast direct product searching
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_inventory_model 
      ON $tableInventory (model_name)
    ''');

    // Index on accessory_group_id for fast compatibility joins
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_inventory_group 
      ON $tableInventory (accessory_group_id)
    ''');

    // Table 2: PhoneModelsTable (Compatibility mapping catalog)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePhoneModels (
        phone_name TEXT PRIMARY KEY NOT NULL,
        accessory_group_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_phone_models_group 
      ON $tablePhoneModels (accessory_group_id)
    ''');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
