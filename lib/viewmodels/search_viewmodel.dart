import 'dart:async';
import 'package:flutter/material.dart';
import '../services/search_service.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchService _searchService;
  Timer? _debounceTimer;

  SearchViewModel({required SearchService searchService})
      : _searchService = searchService;

  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<PhoneSearchResult> _results = [];

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PhoneSearchResult> get results => _results;

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

    // 300ms debounce prevents CPU throttling on low-spec chipsets
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      executeSearch();
    });
  }

  Future<void> executeSearch() async {
    if (_searchQuery.trim().isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _results = await _searchService.searchByPhone(_searchQuery);
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
      _results = [];
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

