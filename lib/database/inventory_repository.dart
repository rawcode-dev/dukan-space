import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';
import '../models/phone_model.dart';
import '../services/diagnostic_service.dart';
import 'db_provider.dart';

class InventoryRepository {
  final DBProvider _dbProvider;

  InventoryRepository({DBProvider? dbProvider})
      : _dbProvider = dbProvider ?? DBProvider.instance;

  // ------------------ Phone Models Queries ------------------

  Future<PhoneModel?> getPhoneModelByName(String phoneName) async {
    try {
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
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getPhoneModelByName failed for "$phoneName"', e, stack);
      rethrow;
    }
  }

  Future<List<PhoneModel>> searchPhoneModels(String query, {int limit = 15}) async {
    try {
      final db = await _dbProvider.database;
      final cleanQuery = '%${query.trim().toLowerCase()}%';
      final results = await db.query(
        DBProvider.tablePhoneModels,
        where: 'LOWER(phone_name) LIKE ?',
        whereArgs: [cleanQuery],
        limit: limit,
        orderBy: 'phone_name ASC',
      );
      final models = results.map((m) => PhoneModel.fromMap(m)).toList();
      DiagnosticService.instance.logInfo('DB_REPO', 'searchPhoneModels("$query") -> found ${models.length} matches');
      return models;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'searchPhoneModels query failed for "$query"', e, stack);
      rethrow;
    }
  }

  Future<List<String>> getCompatibleModelsForGroup(
    String groupId, {
    String? excludeModel,
  }) async {
    try {
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

      final list = results.map((e) => e['phone_name'] as String).toList();
      return list;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getCompatibleModelsForGroup("$groupId") failed', e, stack);
      return [];
    }
  }

  Future<void> bulkUpsertPhoneModels(List<PhoneModel> models) async {
    if (models.isEmpty) return;
    final stopwatch = Stopwatch()..start();
    DiagnosticService.instance.logAction('DB_REPO', 'Starting bulkUpsertPhoneModels', {'count': models.length});
    try {
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
      stopwatch.stop();
      DiagnosticService.instance.logInfo('DB_REPO', 'bulkUpsertPhoneModels completed: ${models.length} models in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'bulkUpsertPhoneModels failed', e, stack);
      rethrow;
    }
  }

  Future<void> bulkReplacePhoneModels(List<PhoneModel> models) async {
    final stopwatch = Stopwatch()..start();
    DiagnosticService.instance.logAction('DB_REPO', 'Starting bulkReplacePhoneModels', {'newCount': models.length});
    try {
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
      stopwatch.stop();
      DiagnosticService.instance.logInfo('DB_REPO', 'bulkReplacePhoneModels completed: ${models.length} models in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'bulkReplacePhoneModels failed', e, stack);
      rethrow;
    }
  }

  // ------------------ Inventory Queries ------------------

  Future<List<InventoryItem>> getInventoryByGroupId(String groupId) async {
    try {
      final db = await _dbProvider.database;
      final results = await db.query(
        DBProvider.tableInventory,
        where: 'accessory_group_id = ?',
        whereArgs: [groupId.trim()],
        orderBy: 'item_type ASC',
      );
      final items = results.map((m) => InventoryItem.fromMap(m)).toList();
      return items;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getInventoryByGroupId("$groupId") failed', e, stack);
      return [];
    }
  }

  Future<List<InventoryItem>> getAllInventory({
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
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
      final items = results.map((m) => InventoryItem.fromMap(m)).toList();
      return items;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getAllInventory(query: "$query") failed', e, stack);
      rethrow;
    }
  }

  Future<int> insertInventory(InventoryItem item) async {
    DiagnosticService.instance.logAction('DB_REPO', 'insertInventory', item.toMap());
    try {
      final db = await _dbProvider.database;
      final id = await db.insert(
        DBProvider.tableInventory,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'insertInventory successful -> generated id: $id');
      return id;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'insertInventory failed for ${item.toMap()}', e, stack);
      rethrow;
    }
  }

  Future<int> upsertInventory(InventoryItem item) async {
    DiagnosticService.instance.logAction('DB_REPO', 'upsertInventory', item.toMap());
    try {
      final db = await _dbProvider.database;
      if (item.id != null) {
        final count = await db.update(
          DBProvider.tableInventory,
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
        if (count > 0) {
          DiagnosticService.instance.logInfo('DB_REPO', 'upsertInventory updated existing item ${item.id}');
          return item.id!;
        }
      }
      final id = await db.insert(
        DBProvider.tableInventory,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'upsertInventory inserted new item $id');
      return id;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'upsertInventory failed for ${item.toMap()}', e, stack);
      rethrow;
    }
  }

  Future<int> updateInventory(InventoryItem item) async {
    DiagnosticService.instance.logAction('DB_REPO', 'updateInventory', item.toMap());
    try {
      final db = await _dbProvider.database;
      final count = await db.update(
        DBProvider.tableInventory,
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'updateInventory row count: $count');
      return count;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'updateInventory failed for id ${item.id}', e, stack);
      rethrow;
    }
  }

  Future<int> deleteInventory(int id) async {
    DiagnosticService.instance.logAction('DB_REPO', 'deleteInventory', {'id': id});
    try {
      final db = await _dbProvider.database;
      final count = await db.delete(
        DBProvider.tableInventory,
        where: 'id = ?',
        whereArgs: [id],
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'deleteInventory deleted $count rows for id $id');
      return count;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'deleteInventory failed for id $id', e, stack);
      rethrow;
    }
  }

  Future<int> updateStockCount(int id, int newStock) async {
    DiagnosticService.instance.logAction('DB_REPO', 'updateStockCount', {'id': id, 'newStock': newStock});
    try {
      final db = await _dbProvider.database;
      final count = await db.update(
        DBProvider.tableInventory,
        {'stock_count': newStock < 0 ? 0 : newStock},
        where: 'id = ?',
        whereArgs: [id],
      );
      return count;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'updateStockCount failed for id $id', e, stack);
      rethrow;
    }
  }

  Future<Map<String, int>> getQuickStats() async {
    try {
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
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getQuickStats failed', e, stack);
      return {'models': 0, 'items': 0, 'stock': 0};
    }
  }

  Future<List<String>> getDistinctGroupIds() async {
    try {
      final db = await _dbProvider.database;
      final results = await db.rawQuery('''
        SELECT DISTINCT accessory_group_id FROM ${DBProvider.tablePhoneModels} WHERE accessory_group_id != ''
        UNION
        SELECT DISTINCT accessory_group_id FROM ${DBProvider.tableInventory} WHERE accessory_group_id != ''
        ORDER BY accessory_group_id ASC
      ''');
      return results.map((r) => r['accessory_group_id'] as String).toList();
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getDistinctGroupIds failed', e, stack);
      return [];
    }
  }

  Future<List<String>> getDistinctShelves() async {
    try {
      final db = await _dbProvider.database;
      final results = await db.rawQuery('''
        SELECT DISTINCT shelf_no FROM ${DBProvider.tableInventory} 
        WHERE shelf_no != '' 
        ORDER BY shelf_no ASC
      ''');
      return results.map((r) => r['shelf_no'] as String).toList();
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getDistinctShelves failed', e, stack);
      return [];
    }
  }

  Future<List<String>> getDistinctBoxes() async {
    try {
      final db = await _dbProvider.database;
      final results = await db.rawQuery('''
        SELECT DISTINCT box_no FROM ${DBProvider.tableInventory} 
        WHERE box_no != '' 
        ORDER BY box_no ASC
      ''');
      return results.map((r) => r['box_no'] as String).toList();
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getDistinctBoxes failed', e, stack);
      return [];
    }
  }
}
