import 'dart:async';
import 'package:flutter/material.dart';
import '../services/diagnostic_service.dart';
import '../services/search_service.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchService _searchService;
  Timer? _debounceTimer;

  SearchViewModel({required SearchService searchService})
      : _searchService = searchService;

  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResultItem> _results = [];

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SearchResultItem> get results => _results;

  void onQueryChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _results = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // 250ms debounce prevents unnecessary queries while user is typing
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      executeSearch();
    });
  }

  Future<void> executeSearch() async {
    final clean = _searchQuery.trim();
    if (clean.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _searchService.search(clean);
    } catch (e, stack) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _results = [];
      DiagnosticService.instance.logError('SEARCH_VM', 'executeSearch failed for "$clean"', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
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
