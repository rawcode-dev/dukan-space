import '../database/inventory_repository.dart';
import '../models/inventory_item.dart';
import 'diagnostic_service.dart';

class SearchResultItem {
  final InventoryItem item;
  final List<String> alsoFitsModels;
  final String? matchedPhoneModel;

  const SearchResultItem({
    required this.item,
    this.alsoFitsModels = const [],
    this.matchedPhoneModel,
  });
}

class SearchService {
  final InventoryRepository _repository;

  SearchService({required InventoryRepository repository})
      : _repository = repository;

  Future<List<SearchResultItem>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final stopwatch = Stopwatch()..start();
    DiagnosticService.instance.logAction('SEARCH', 'Search initiated', {'query': clean});

    try {
      final Map<int, SearchResultItem> resultMap = {};

      // 1. DIRECT INVENTORY SEARCH (Product model name, category, shelf, box, group)
      final directItems = await _repository.searchInventoryDirect(clean);
      for (final item in directItems) {
        if (item.id == null) continue;
        List<String> alsoFits = [];
        if (item.accessoryGroupId.isNotEmpty) {
          alsoFits = await _repository.getCompatibleModelsForGroup(
            item.accessoryGroupId,
            excludeModel: item.modelName,
          );
        }
        resultMap[item.id!] = SearchResultItem(
          item: item,
          alsoFitsModels: alsoFits,
          matchedPhoneModel: item.modelName.isNotEmpty ? item.modelName : null,
        );
      }

      // 2. COMPATIBILITY CATALOG SEARCH (Lookup phone models in catalog)
      final matchedModels = await _repository.searchPhoneModels(clean, limit: 10);
      for (final model in matchedModels) {
        final groupItems = await _repository.getInventoryByGroupId(model.accessoryGroupId);
        final compatibleModels = await _repository.getCompatibleModelsForGroup(
          model.accessoryGroupId,
          excludeModel: model.phoneName,
        );

        for (final item in groupItems) {
          if (item.id != null && !resultMap.containsKey(item.id)) {
            resultMap[item.id!] = SearchResultItem(
              item: item,
              alsoFitsModels: compatibleModels,
              matchedPhoneModel: model.phoneName,
            );
          }
        }
      }

      final results = resultMap.values.toList();
      stopwatch.stop();

      DiagnosticService.instance.logInfo(
        'SEARCH',
        'Search for "$clean" completed in ${stopwatch.elapsedMilliseconds}ms: ${results.length} inventory items found (${directItems.length} direct, ${matchedModels.length} catalog models matched)',
      );

      return results;
    } catch (e, stack) {
      DiagnosticService.instance.logError('SEARCH', 'Search failed for "$clean"', e, stack);
      rethrow;
    }
  }

  // Backwards compatibility alias
  Future<List<SearchResultItem>> searchByPhone(String query) => search(query);
}
