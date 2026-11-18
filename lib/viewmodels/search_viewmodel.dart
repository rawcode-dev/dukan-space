import 'dart:async';
import 'package:flutter/material.dart';
import '../database/inventory_repository.dart';
import '../models/location_summary_item.dart';
import '../services/diagnostic_service.dart';
import '../services/search_service.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchService _searchService;
  final InventoryRepository _repository;
  Timer? _debounceTimer;

  SearchViewModel({
    required SearchService searchService,
    required InventoryRepository repository,
  })  : _searchService = searchService,
        _repository = repository;

  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResultItem> _results = [];

  // Location filter & Inspector states
  String? _selectedShelf;
  String? _selectedBox;
  List<String> _availableShelves = [];
  List<String> _availableBoxes = [];
  List<LocationSummaryItem> _locationSummaries = [];
  bool _isLoadingLocations = false;

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SearchResultItem> get results => _results;

  String? get selectedShelf => _selectedShelf;
  String? get selectedBox => _selectedBox;
  List<String> get availableShelves => _availableShelves;
  List<String> get availableBoxes => _availableBoxes;
  List<LocationSummaryItem> get locationSummaries => _locationSummaries;
  bool get isLoadingLocations => _isLoadingLocations;

  bool get isLocationFilterActive =>
      (_selectedShelf != null && _selectedShelf!.trim().isNotEmpty) ||
      (_selectedBox != null && _selectedBox!.trim().isNotEmpty);

  String get locationFilterLabel {
    final s = _selectedShelf?.trim() ?? '';
    final b = _selectedBox?.trim() ?? '';
    if (s.isNotEmpty && b.isNotEmpty) {
      return 'Shelf: $s • Box: $b';
    } else if (s.isNotEmpty) {
      return 'Shelf: $s';
    } else if (b.isNotEmpty) {
      return 'Box: $b';
    }
    return '';
  }

  void onQueryChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty && !isLocationFilterActive) {
      _results = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // 250ms debounce prevents unnecessary queries while typing
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      executeSearch();
    });
  }

  Future<void> executeSearch() async {
    final clean = _searchQuery.trim();
    if (clean.isEmpty && !isLocationFilterActive) {
      _results = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _searchService.search(
        clean,
        shelfNo: _selectedShelf,
        boxNo: _selectedBox,
      );
    } catch (e, stack) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _results = [];
      DiagnosticService.instance.logError('SEARCH_VM', 'executeSearch failed for "$clean"', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all distinct shelves and aggregated shelf/box locations
  Future<void> loadLocationMetadata() async {
    _isLoadingLocations = true;
    notifyListeners();

    try {
      _availableShelves = await _repository.getDistinctShelves();
      _locationSummaries = await _repository.getLocationSummary();
      if (_selectedShelf != null && _selectedShelf!.isNotEmpty) {
        _availableBoxes = await _repository.getBoxesForShelf(_selectedShelf!);
      }
    } catch (e, stack) {
      DiagnosticService.instance.logError('SEARCH_VM', 'loadLocationMetadata failed', e, stack);
    } finally {
      _isLoadingLocations = false;
      notifyListeners();
    }
  }

  /// Selects a shelf and fetches boxes existing on that shelf
  Future<void> selectShelf(String? shelf) async {
    _selectedShelf = shelf?.trim();
    _selectedBox = null;
    _availableBoxes = [];
    notifyListeners();

    if (_selectedShelf != null && _selectedShelf!.isNotEmpty) {
      try {
        _availableBoxes = await _repository.getBoxesForShelf(_selectedShelf!);
      } catch (e) {
        DiagnosticService.instance.logError('SEARCH_VM', 'selectShelf boxes lookup failed', e);
      }
      notifyListeners();
    }
  }

  void selectBox(String? box) {
    _selectedBox = box?.trim();
    notifyListeners();
  }

  /// Applies location filter and re-executes search immediately
  Future<void> applyLocationFilter({String? shelf, String? box}) async {
    _selectedShelf = shelf?.trim().isNotEmpty == true ? shelf!.trim() : null;
    _selectedBox = box?.trim().isNotEmpty == true ? box!.trim() : null;
    notifyListeners();

    await executeSearch();
  }

  /// Clears location filter
  void clearLocationFilter() {
    _selectedShelf = null;
    _selectedBox = null;
    _availableBoxes = [];
    if (_searchQuery.trim().isNotEmpty) {
      executeSearch();
    } else {
      _results = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _selectedShelf = null;
    _selectedBox = null;
    _availableBoxes = [];
    _results = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
