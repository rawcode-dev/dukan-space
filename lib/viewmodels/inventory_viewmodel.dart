import 'package:flutter/material.dart';
import '../database/inventory_repository.dart';
import '../models/inventory_item.dart';
import '../services/diagnostic_service.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _repository;

  InventoryViewModel({required InventoryRepository repository})
      : _repository = repository {
    loadInventory();
  }

  List<InventoryItem> _items = [];
  bool _isLoading = false;
  String? _filterQuery;
  String? _errorMessage;
  Map<String, int> _stats = {'models': 0, 'items': 0, 'stock': 0};

  List<String> _existingModels = [];
  List<String> _existingGroups = [];
  List<String> _existingShelves = [];
  List<String> _existingBoxes = [];

  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get filterQuery => _filterQuery;
  String? get errorMessage => _errorMessage;
  Map<String, int> get stats => _stats;

  List<String> get existingModels => _existingModels;
  List<String> get existingGroups => _existingGroups;
  List<String> get existingShelves => _existingShelves;
  List<String> get existingBoxes => _existingBoxes;

  Future<void> loadInventory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _repository.getAllInventory(query: _filterQuery);
      _stats = await _repository.getQuickStats();
      await loadMetadata();
      DiagnosticService.instance.logInfo(
        'INVENTORY_VM',
        'Loaded ${_items.length} inventory items. Total models: ${_stats["models"]}, total stock: ${_stats["stock"]}',
      );
    } catch (e, stack) {
      _errorMessage = 'Failed to load inventory: ${e.toString()}';
      DiagnosticService.instance.logError('INVENTORY_VM', 'loadInventory failed', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMetadata() async {
    try {
      _existingModels = await _repository.getDistinctModelNames();
      _existingGroups = await _repository.getDistinctGroupIds();
      _existingShelves = await _repository.getDistinctShelves();
      _existingBoxes = await _repository.getDistinctBoxes();
    } catch (e) {
      DiagnosticService.instance.logError('INVENTORY_VM', 'loadMetadata failed', e);
    }
  }

  Future<String?> findAutoGroup(String modelName) async {
    return await _repository.findGroupIdForModel(modelName);
  }

  void filterInventory(String query) {
    _filterQuery = query.isEmpty ? null : query;
    DiagnosticService.instance.logAction('INVENTORY_VM', 'filterInventory applied', {'filter': query});
    loadInventory();
  }

  Future<bool> saveOrUpdateItem(InventoryItem item) async {
    _errorMessage = null;

    final itemToSave = item;

    DiagnosticService.instance.logAction(
      'INVENTORY_VM',
      itemToSave.id == null ? 'saveNewItem' : 'updateItem',
      itemToSave.toMap(),
    );

    try {
      if (itemToSave.id == null) {
        await _repository.insertInventory(itemToSave);
      } else {
        await _repository.updateInventory(itemToSave);
      }
      await loadInventory();
      DiagnosticService.instance.logInfo(
        'INVENTORY_VM',
        'Item saved successfully: ${itemToSave.displayName} (Group: ${itemToSave.accessoryGroupId.isEmpty ? "None" : itemToSave.accessoryGroupId})',
      );
      return true;
    } catch (e, stack) {
      _errorMessage = e.toString();
      DiagnosticService.instance.logError('INVENTORY_VM', 'saveOrUpdateItem failed', e, stack);
      notifyListeners();
      return false;
    }
  }

  Future<void> adjustStock(int id, int delta) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;

    final current = _items[index];
    final updatedStock = (current.stockCount + delta).clamp(0, 999999);

    DiagnosticService.instance.logAction('INVENTORY_VM', 'adjustStock', {
      'id': id,
      'name': current.displayName,
      'oldStock': current.stockCount,
      'newStock': updatedStock,
      'delta': delta,
    });

    // Optimistic UI update for low-spec responsiveness
    _items[index] = current.copyWith(stockCount: updatedStock);
    notifyListeners();

    try {
      await _repository.updateStockCount(id, updatedStock);
      _stats = await _repository.getQuickStats();
    } catch (e) {
      DiagnosticService.instance.logError('INVENTORY_VM', 'adjustStock failed for id $id', e);
    }
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    DiagnosticService.instance.logAction('INVENTORY_VM', 'deleteItem initiated', {'id': id});
    try {
      await _repository.deleteInventory(id);
      await loadInventory();
      DiagnosticService.instance.logInfo('INVENTORY_VM', 'Item $id deleted successfully');
    } catch (e, stack) {
      _errorMessage = e.toString();
      DiagnosticService.instance.logError('INVENTORY_VM', 'deleteItem failed for id $id', e, stack);
      notifyListeners();
    }
  }
}
