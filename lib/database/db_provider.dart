import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DBProvider {
  DBProvider._internal();
  static final DBProvider instance = DBProvider._internal();

  static const String _databaseName = 'dukan_space_inventory.db';
  static const int _databaseVersion = 1;

  static const String tableInventory = 'inventory';
  static const String tablePhoneModels = 'phone_models';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    final path = join(docsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Optimizations for low-end Android hardware
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA synchronous = NORMAL;');
        await db.execute('PRAGMA cache_size = 2000;');
        await db.execute('PRAGMA temp_store = MEMORY;');
      },
      onCreate: (db, version) async {
        // Table 1: InventoryTable
        await db.execute('''
          CREATE TABLE $tableInventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accessory_group_id TEXT NOT NULL,
            item_type TEXT NOT NULL,
            shelf_no TEXT NOT NULL,
            box_no TEXT NOT NULL,
            stock_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Index on accessory_group_id
        await db.execute('''
          CREATE INDEX idx_inventory_group 
          ON $tableInventory (accessory_group_id)
        ''');

        // Table 2: PhoneModelsTable
        await db.execute('''
          CREATE TABLE $tablePhoneModels (
            phone_name TEXT PRIMARY KEY NOT NULL,
            accessory_group_id TEXT NOT NULL
          )
        ''');

        // Indexes for PhoneModelsTable
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_phone_name 
          ON $tablePhoneModels (phone_name)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_phone_models_group 
          ON $tablePhoneModels (accessory_group_id)
        ''');
      },
    );
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}

