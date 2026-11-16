import 'package:flutter/material.dart';
import '../database/inventory_repository.dart';
import '../models/inventory_item.dart';

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

  List<String> _existingGroups = [];
  List<String> _existingShelves = [];
  List<String> _existingBoxes = [];

  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get filterQuery => _filterQuery;
  String? get errorMessage => _errorMessage;
  Map<String, int> get stats => _stats;

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
    } catch (e) {
      _errorMessage = 'Failed to load inventory: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMetadata() async {
    try {
      _existingGroups = await _repository.getDistinctGroupIds();
      _existingShelves = await _repository.getDistinctShelves();
      _existingBoxes = await _repository.getDistinctBoxes();
    } catch (e) {
      debugPrint('Failed to load metadata: $e');
    }
  }

  void filterInventory(String query) {
    _filterQuery = query.isEmpty ? null : query;
    loadInventory();
  }

  Future<bool> saveOrUpdateItem(InventoryItem item) async {
    _errorMessage = null;
    try {
      if (item.id == null) {
        await _repository.insertInventory(item);
      } else {
        await _repository.updateInventory(item);
      }
      await loadInventory();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error saving item: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> adjustStock(int id, int delta) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;

    final current = _items[index];
    final updatedStock = (current.stockCount + delta).clamp(0, 999999);

    // Optimistic UI update for low-spec responsiveness
    _items[index] = current.copyWith(stockCount: updatedStock);
    notifyListeners();

    try {
      await _repository.updateStockCount(id, updatedStock);
      _stats = await _repository.getQuickStats();
    } catch (e) {
      debugPrint('Error updating stock: $e');
    }
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    try {
      await _repository.deleteInventory(id);
      await loadInventory();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
