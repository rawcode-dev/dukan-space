import 'package:sqflite/sqflite.dart';
import '../models/accessory_group.dart';
import '../models/inventory_item.dart';
import '../models/phone_model.dart';
import '../services/diagnostic_service.dart';
import 'db_provider.dart';

class InventoryRepository {
  final DBProvider _dbProvider;

  InventoryRepository({DBProvider? dbProvider})
      : _dbProvider = dbProvider ?? DBProvider.instance;

  // ------------------ Phone Models / Compatibility Queries ------------------

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

  /// Looks up whether an exact phone model exists in the catalog and returns its group ID.
  /// Uses strict exact matching (trimmed and case-insensitive) to prevent accidental
  /// cross-series grouping (e.g. iPhone 17 must NOT match iPhone 14 group).
  Future<String?> findGroupIdForModel(String modelName) async {
    final clean = modelName.trim().toLowerCase();
    if (clean.isEmpty) return null;
    try {
      final db = await _dbProvider.database;

      // Strict exact match only: phone_name equals modelName (case-insensitive)
      final exact = await db.query(
        DBProvider.tablePhoneModels,
        columns: ['accessory_group_id'],
        where: 'LOWER(TRIM(phone_name)) = ?',
        whereArgs: [clean],
        limit: 1,
      );
      if (exact.isNotEmpty) {
        final gid = exact.first['accessory_group_id'] as String?;
        if (gid != null && gid.trim().isNotEmpty) {
          DiagnosticService.instance.logInfo('DB_REPO', 'Exact group match found: "$modelName" -> "$gid"');
          return gid.trim();
        }
      }

      return null;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'findGroupIdForModel failed for "$modelName"', e, stack);
      return null;
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
      return models;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'searchPhoneModels failed for "$query"', e, stack);
      rethrow;
    }
  }

  Future<List<String>> getCompatibleModelsForGroup(
    String groupId, {
    String? excludeModel,
  }) async {
    if (groupId.trim().isEmpty) return [];
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

  // ------------------ Direct Inventory Queries ------------------

  Future<List<InventoryItem>> getInventoryByGroupId(String groupId) async {
    if (groupId.trim().isEmpty) return [];
    try {
      final db = await _dbProvider.database;
      final results = await db.query(
        DBProvider.tableInventory,
        where: 'accessory_group_id = ?',
        whereArgs: [groupId.trim()],
        orderBy: 'id DESC',
      );
      final items = results.map((m) => InventoryItem.fromMap(m)).toList();
      return items;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getInventoryByGroupId("$groupId") failed', e, stack);
      return [];
    }
  }

  Future<List<InventoryItem>> searchInventoryDirect(String query, {int limit = 50}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];
    try {
      final db = await _dbProvider.database;
      final pattern = '%$clean%';
      final results = await db.query(
        DBProvider.tableInventory,
        where: 'LOWER(model_name) LIKE ? OR LOWER(item_type) LIKE ? OR LOWER(accessory_group_id) LIKE ? OR LOWER(shelf_no) LIKE ? OR LOWER(box_no) LIKE ?',
        whereArgs: [pattern, pattern, pattern, pattern, pattern],
        limit: limit,
        orderBy: 'id DESC',
      );
      return results.map((m) => InventoryItem.fromMap(m)).toList();
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'searchInventoryDirect failed for "$query"', e, stack);
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
        where = 'LOWER(model_name) LIKE ? OR LOWER(accessory_group_id) LIKE ? OR LOWER(item_type) LIKE ? OR LOWER(shelf_no) LIKE ? OR LOWER(box_no) LIKE ?';
        whereArgs = [clean, clean, clean, clean, clean];
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
      DiagnosticService.instance.logInfo('DB_REPO', 'insertInventory successful -> id: $id');
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
          DiagnosticService.instance.logInfo('DB_REPO', 'upsertInventory updated item ${item.id}');
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
      DiagnosticService.instance.logInfo('DB_REPO', 'updateInventory rows affected: $count');
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

  Future<List<String>> getDistinctModelNames() async {
    try {
      final db = await _dbProvider.database;
      final results = await db.rawQuery('''
        SELECT DISTINCT phone_name AS name FROM ${DBProvider.tablePhoneModels} WHERE phone_name != ''
        UNION
        SELECT DISTINCT model_name AS name FROM ${DBProvider.tableInventory} WHERE model_name != ''
        ORDER BY name ASC
      ''');
      return results.map((r) => r['name'] as String).toList();
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getDistinctModelNames failed', e, stack);
      return [];
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

  // ------------------ Group Management ------------------

  /// Retrieves all groups with their list of phone models and inventory stock stats
  Future<List<AccessoryGroup>> getAllGroupsWithDetails() async {
    try {
      final db = await _dbProvider.database;

      // 1. Fetch all phone models grouped by accessory_group_id
      final modelResults = await db.rawQuery('''
        SELECT accessory_group_id, phone_name 
        FROM ${DBProvider.tablePhoneModels} 
        WHERE accessory_group_id != '' 
        ORDER BY accessory_group_id ASC, phone_name ASC
      ''');

      final Map<String, List<String>> groupModelsMap = {};
      for (final row in modelResults) {
        final gid = row['accessory_group_id'] as String;
        final model = row['phone_name'] as String;
        groupModelsMap.putIfAbsent(gid, () => []).add(model);
      }

      // 2. Fetch inventory summary by accessory_group_id
      final invSummary = await db.rawQuery('''
        SELECT accessory_group_id, COUNT(*) as item_count, SUM(stock_count) as total_stock 
        FROM ${DBProvider.tableInventory} 
        WHERE accessory_group_id != '' 
        GROUP BY accessory_group_id
      ''');

      final Map<String, int> invCountMap = {};
      final Map<String, int> invStockMap = {};
      for (final row in invSummary) {
        final gid = row['accessory_group_id'] as String;
        final count = (row['item_count'] as int?) ?? 0;
        final stock = (row['total_stock'] as int?) ?? (row['total_stock'] as num?)?.toInt() ?? 0;
        invCountMap[gid] = count;
        invStockMap[gid] = stock;
      }

      // 3. Union of all distinct group IDs from both tables
      final allGids = <String>{...groupModelsMap.keys, ...invCountMap.keys}.toList()..sort();

      final List<AccessoryGroup> groups = [];
      for (final gid in allGids) {
        final models = groupModelsMap[gid] ?? [];
        final count = invCountMap[gid] ?? 0;
        final stock = invStockMap[gid] ?? 0;
        groups.add(AccessoryGroup(
          groupId: gid,
          phoneModels: models,
          inventoryItemCount: count,
          totalStockCount: stock,
        ));
      }

      return groups;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'getAllGroupsWithDetails failed', e, stack);
      return [];
    }
  }

  /// Generates a clean, unique group ID if none is provided by user
  Future<String> generateUniqueGroupId(List<String> phoneModels) async {
    final db = await _dbProvider.database;
    String base;
    if (phoneModels.isNotEmpty && phoneModels.first.trim().isNotEmpty) {
      final sanitized = phoneModels.first
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .toUpperCase();
      base = 'GRP-$sanitized';
    } else {
      final rand = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      base = 'GRP-$rand';
    }

    String candidate = base;
    int counter = 1;
    while (true) {
      final existing = await db.query(
        DBProvider.tablePhoneModels,
        columns: ['accessory_group_id'],
        where: 'LOWER(accessory_group_id) = ?',
        whereArgs: [candidate.toLowerCase()],
        limit: 1,
      );
      if (existing.isEmpty) {
        break;
      }
      counter++;
      candidate = '$base-$counter';
    }
    return candidate;
  }

  /// Creates a new group or updates an existing group with its phone models.
  /// If [newGroupId] is empty, a clean unique group ID is automatically generated.
  Future<String> createOrUpdateGroup({
    String? oldGroupId,
    required String newGroupId,
    required List<String> phoneModels,
    bool updateInventory = true,
  }) async {
    var cleanNewGid = newGroupId.trim();
    if (cleanNewGid.isEmpty) {
      cleanNewGid = await generateUniqueGroupId(phoneModels);
    }

    final cleanOldGid = oldGroupId?.trim();
    final isRenaming = cleanOldGid != null && cleanOldGid.isNotEmpty && cleanOldGid != cleanNewGid;

    DiagnosticService.instance.logAction('DB_REPO', 'createOrUpdateGroup', {
      'oldGroupId': cleanOldGid,
      'newGroupId': cleanNewGid,
      'modelCount': phoneModels.length,
      'updateInventory': updateInventory,
    });

    try {
      final db = await _dbProvider.database;
      await db.transaction((txn) async {
        // 1. If renaming, update inventory records if requested
        if (isRenaming && updateInventory) {
          await txn.update(
            DBProvider.tableInventory,
            {'accessory_group_id': cleanNewGid},
            where: 'accessory_group_id = ?',
            whereArgs: [cleanOldGid],
          );
        }

        // 2. Remove previous phone model mappings for the target/old group
        if (isRenaming) {
          await txn.delete(
            DBProvider.tablePhoneModels,
            where: 'accessory_group_id = ?',
            whereArgs: [cleanOldGid],
          );
        }
        await txn.delete(
          DBProvider.tablePhoneModels,
          where: 'accessory_group_id = ?',
          whereArgs: [cleanNewGid],
        );

        // 3. Insert fresh phone model mappings
        final batch = txn.batch();
        final seen = <String>{};
        for (final rawModel in phoneModels) {
          final modelName = rawModel.trim();
          if (modelName.isEmpty) continue;
          if (seen.contains(modelName.toLowerCase())) continue;
          seen.add(modelName.toLowerCase());

          batch.insert(
            DBProvider.tablePhoneModels,
            {
              'phone_name': modelName,
              'accessory_group_id': cleanNewGid,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      DiagnosticService.instance.logInfo('DB_REPO', 'createOrUpdateGroup succeeded: "$cleanNewGid" with ${phoneModels.length} models');
      return cleanNewGid;
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'createOrUpdateGroup failed for "$cleanNewGid"', e, stack);
      rethrow;
    }
  }

  /// Deletes a compatibility group and optionally unlinks inventory items
  Future<void> deleteGroup(String groupId, {bool clearFromInventory = false}) async {
    final cleanGid = groupId.trim();
    if (cleanGid.isEmpty) return;

    DiagnosticService.instance.logAction('DB_REPO', 'deleteGroup', {
      'groupId': cleanGid,
      'clearFromInventory': clearFromInventory,
    });

    try {
      final db = await _dbProvider.database;
      await db.transaction((txn) async {
        // 1. Delete all phone model entries for this group
        await txn.delete(
          DBProvider.tablePhoneModels,
          where: 'accessory_group_id = ?',
          whereArgs: [cleanGid],
        );

        // 2. Optionally clear from inventory
        if (clearFromInventory) {
          await txn.update(
            DBProvider.tableInventory,
            {'accessory_group_id': ''},
            where: 'accessory_group_id = ?',
            whereArgs: [cleanGid],
          );
        }
      });
      DiagnosticService.instance.logInfo('DB_REPO', 'deleteGroup succeeded: "$cleanGid"');
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'deleteGroup failed for "$cleanGid"', e, stack);
      rethrow;
    }
  }

  /// Adds a single model to a group
  Future<void> addModelToGroup(String groupId, String phoneName) async {
    final cleanGid = groupId.trim();
    final cleanName = phoneName.trim();
    if (cleanGid.isEmpty || cleanName.isEmpty) return;

    try {
      final db = await _dbProvider.database;
      await db.insert(
        DBProvider.tablePhoneModels,
        {
          'phone_name': cleanName,
          'accessory_group_id': cleanGid,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'addModelToGroup: added "$cleanName" to "$cleanGid"');
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'addModelToGroup failed for "$cleanName" -> "$cleanGid"', e, stack);
      rethrow;
    }
  }

  /// Removes a single phone model from its group
  Future<void> removeModelFromGroup(String phoneName) async {
    final cleanName = phoneName.trim();
    if (cleanName.isEmpty) return;

    try {
      final db = await _dbProvider.database;
      await db.delete(
        DBProvider.tablePhoneModels,
        where: 'LOWER(phone_name) = ?',
        whereArgs: [cleanName.toLowerCase()],
      );
      DiagnosticService.instance.logInfo('DB_REPO', 'removeModelFromGroup: removed "$cleanName"');
    } catch (e, stack) {
      DiagnosticService.instance.logError('DB_REPO', 'removeModelFromGroup failed for "$cleanName"', e, stack);
      rethrow;
    }
  }
}
