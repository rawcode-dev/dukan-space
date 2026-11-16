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
  Map<String, int> _stats = {'models': 0, 'items': 0, 'stock': 0};

  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get filterQuery => _filterQuery;
  Map<String, int> get stats => _stats;

  Future<void> loadInventory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _repository.getAllInventory(query: _filterQuery);
      _stats = await _repository.getQuickStats();
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterInventory(String query) {
    _filterQuery = query.isEmpty ? null : query;
    loadInventory();
  }

  Future<bool> saveOrUpdateItem(InventoryItem item) async {
    try {
      if (item.id == null) {
        await _repository.insertInventory(item);
      } else {
        await _repository.updateInventory(item);
      }
      await loadInventory();
      return true;
    } catch (e) {
      debugPrint('Error saving item: $e');
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

    await _repository.updateStockCount(id, updatedStock);
    _stats = await _repository.getQuickStats();
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteInventory(id);
    await loadInventory();
  }
}

