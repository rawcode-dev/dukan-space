import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';
import '../models/phone_model.dart';
import 'db_provider.dart';

class InventoryRepository {
  final DBProvider _dbProvider;

  InventoryRepository({DBProvider? dbProvider})
      : _dbProvider = dbProvider ?? DBProvider.instance;

  // ------------------ Phone Models Queries ------------------

  Future<PhoneModel?> getPhoneModelByName(String phoneName) async {
    final db = await _dbProvider.database;
    final results = await db.query(
      DBProvider.tablePhoneModels,
      where: 'LOWER(phone_name) = ?',
      whereArgs: [phoneName.trim().toLowerCase()],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return PhoneModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<PhoneModel>> searchPhoneModels(String query, {int limit = 15}) async {
    final db = await _dbProvider.database;
    final cleanQuery = '%${query.trim().toLowerCase()}%';
    final results = await db.query(
      DBProvider.tablePhoneModels,
      where: 'LOWER(phone_name) LIKE ?',
      whereArgs: [cleanQuery],
      limit: limit,
      orderBy: 'phone_name ASC',
    );
    return results.map((m) => PhoneModel.fromMap(m)).toList();
  }

  Future<List<String>> getCompatibleModelsForGroup(
    String groupId, {
    String? excludeModel,
  }) async {
    final db = await _dbProvider.database;
    final whereClause = excludeModel != null
        ? 'accessory_group_id = ? AND LOWER(phone_name) != ?'
        : 'accessory_group_id = ?';
    final whereArgs = excludeModel != null
        ? [groupId.trim(), excludeModel.trim().toLowerCase()]
        : [groupId.trim()];

    final results = await db.query(
      DBProvider.tablePhoneModels,
      columns: ['phone_name'],
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'phone_name ASC',
    );

    return results.map((e) => e['phone_name'] as String).toList();
  }

  Future<void> bulkUpsertPhoneModels(List<PhoneModel> models) async {
    if (models.isEmpty) return;
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final model in models) {
        batch.insert(
          DBProvider.tablePhoneModels,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> bulkReplacePhoneModels(List<PhoneModel> models) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn.delete(DBProvider.tablePhoneModels);
      if (models.isNotEmpty) {
        final batch = txn.batch();
        for (final model in models) {
          batch.insert(
            DBProvider.tablePhoneModels,
            model.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  // ------------------ Inventory Queries ------------------

  Future<List<InventoryItem>> getInventoryByGroupId(String groupId) async {
    final db = await _dbProvider.database;
    final results = await db.query(
      DBProvider.tableInventory,
      where: 'accessory_group_id = ?',
      whereArgs: [groupId.trim()],
      orderBy: 'item_type ASC',
    );
    return results.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<List<InventoryItem>> getAllInventory({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbProvider.database;
    String? where;
    List<dynamic>? whereArgs;

    if (query != null && query.trim().isNotEmpty) {
      final clean = '%${query.trim().toLowerCase()}%';
      where = 'LOWER(accessory_group_id) LIKE ? OR LOWER(item_type) LIKE ? OR LOWER(shelf_no) LIKE ? OR LOWER(box_no) LIKE ?';
      whereArgs = [clean, clean, clean, clean];
    }

    final results = await db.query(
      DBProvider.tableInventory,
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'id DESC',
    );
    return results.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<int> insertInventory(InventoryItem item) async {
    final db = await _dbProvider.database;
    return await db.insert(
      DBProvider.tableInventory,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> upsertInventory(InventoryItem item) async {
    final db = await _dbProvider.database;
    if (item.id != null) {
      final count = await db.update(
        DBProvider.tableInventory,
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (count > 0) return item.id!;
    }
    return await db.insert(
      DBProvider.tableInventory,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateInventory(InventoryItem item) async {
    final db = await _dbProvider.database;
    return await db.update(
      DBProvider.tableInventory,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteInventory(int id) async {
    final db = await _dbProvider.database;
    return await db.delete(
      DBProvider.tableInventory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStockCount(int id, int newStock) async {
    final db = await _dbProvider.database;
    return await db.update(
      DBProvider.tableInventory,
      {'stock_count': newStock < 0 ? 0 : newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getQuickStats() async {
    final db = await _dbProvider.database;
    final totalModelsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${DBProvider.tablePhoneModels}'),
        ) ?? 0;
    final totalInventoryCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${DBProvider.tableInventory}'),
        ) ?? 0;
    final totalStockCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT SUM(stock_count) FROM ${DBProvider.tableInventory}'),
        ) ?? 0;

    return {
      'models': totalModelsCount,
      'items': totalInventoryCount,
      'stock': totalStockCount,
    };
  }
}

