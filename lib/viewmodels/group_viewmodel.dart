import 'package:flutter/foundation.dart';
import '../database/inventory_repository.dart';
import '../models/accessory_group.dart';
import '../services/diagnostic_service.dart';

class GroupViewModel extends ChangeNotifier {
  final InventoryRepository _repository;

  GroupViewModel({required InventoryRepository repository})
      : _repository = repository {
    loadGroups();
  }

  List<AccessoryGroup> _allGroups = [];
  List<AccessoryGroup> _filteredGroups = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  List<AccessoryGroup> get groups => _filteredGroups;
  List<AccessoryGroup> get allGroups => _allGroups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  int get totalGroupCount => _allGroups.length;
  int get totalMappedModels =>
      _allGroups.fold<int>(0, (sum, g) => sum + g.phoneModels.length);

  Future<void> loadGroups() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allGroups = await _repository.getAllGroupsWithDetails();
      _applyFilter();
      DiagnosticService.instance.logInfo(
        'GROUP_VM',
        'Loaded ${_allGroups.length} groups with $totalMappedModels phone models',
      );
    } catch (e, stack) {
      _errorMessage = 'Failed to load groups: $e';
      DiagnosticService.instance.logError('GROUP_VM', 'loadGroups error', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterGroups(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredGroups = List.from(_allGroups);
    } else {
      _filteredGroups = _allGroups.where((g) {
        final matchesId = g.groupId.toLowerCase().contains(q);
        final matchesModel = g.phoneModels.any((m) => m.toLowerCase().contains(q));
        return matchesId || matchesModel;
      }).toList();
    }
  }

  Future<bool> saveGroup({
    String? oldGroupId,
    required String newGroupId,
    required List<String> phoneModels,
    bool updateInventory = true,
  }) async {
    final cleanGid = newGroupId.trim();
    if (cleanGid.isEmpty) {
      _errorMessage = 'Group ID cannot be empty.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createOrUpdateGroup(
        oldGroupId: oldGroupId,
        newGroupId: cleanGid,
        phoneModels: phoneModels,
        updateInventory: updateInventory,
      );
      await loadGroups();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to save group "$cleanGid": $e';
      DiagnosticService.instance.logError('GROUP_VM', 'saveGroup error', e, stack);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId, {bool clearFromInventory = false}) async {
    final cleanGid = groupId.trim();
    if (cleanGid.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteGroup(cleanGid, clearFromInventory: clearFromInventory);
      await loadGroups();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to delete group "$cleanGid": $e';
      DiagnosticService.instance.logError('GROUP_VM', 'deleteGroup error', e, stack);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addModelToGroup(String groupId, String phoneName) async {
    final cleanGid = groupId.trim();
    final cleanName = phoneName.trim();
    if (cleanGid.isEmpty || cleanName.isEmpty) return false;

    try {
      await _repository.addModelToGroup(cleanGid, cleanName);
      await loadGroups();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to add "$cleanName" to "$cleanGid": $e';
      DiagnosticService.instance.logError('GROUP_VM', 'addModelToGroup error', e, stack);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeModelFromGroup(String groupId, String phoneName) async {
    final cleanName = phoneName.trim();
    if (cleanName.isEmpty) return false;

    try {
      await _repository.removeModelFromGroup(cleanName);
      await loadGroups();
      return true;
    } catch (e, stack) {
      _errorMessage = 'Failed to remove model "$cleanName": $e';
      DiagnosticService.instance.logError('GROUP_VM', 'removeModelFromGroup error', e, stack);
      notifyListeners();
      return false;
    }
  }
}

