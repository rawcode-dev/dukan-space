import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBProvider {
  DBProvider._internal();
  static final DBProvider instance = DBProvider._internal();

  static const String _databaseName = 'dukan_space_inventory.db';
  static const int _databaseVersion = 2;

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
        // Safe PRAGMA execution in onOpen (outside transactions)
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA cache_size = 2000;');
          await db.execute('PRAGMA temp_store = MEMORY;');
        } catch (_) {
          // Fallback gracefully on devices that don't support custom PRAGMAs
        }
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Table 1: InventoryTable
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accessory_group_id TEXT NOT NULL,
        item_type TEXT NOT NULL,
        shelf_no TEXT NOT NULL,
        box_no TEXT NOT NULL,
        stock_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Index on accessory_group_id for fast joins/lookups
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_inventory_group 
      ON $tableInventory (accessory_group_id)
    ''');

    // Table 2: PhoneModelsTable
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePhoneModels (
        phone_name TEXT PRIMARY KEY NOT NULL,
        accessory_group_id TEXT NOT NULL
      )
    ''');

    // Index on accessory_group_id
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
