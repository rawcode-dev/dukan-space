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

  Future<List<SearchResultItem>> search(
    String query, {
    String? shelfNo,
    String? boxNo,
  }) async {
    final clean = query.trim();
    final hasLocation = (shelfNo != null && shelfNo.trim().isNotEmpty) ||
        (boxNo != null && boxNo.trim().isNotEmpty);

    if (clean.isEmpty && !hasLocation) return [];

    final stopwatch = Stopwatch()..start();
    DiagnosticService.instance.logAction('SEARCH', 'Search initiated', {
      'query': clean,
      'shelfNo': shelfNo,
      'boxNo': boxNo,
    });

    try {
      final Map<int, SearchResultItem> resultMap = {};

      if (clean.isEmpty && hasLocation) {
        // Location-only search: fetch everything in this shelf / box
        final items = await _repository.getInventoryByLocation(
          shelfNo: shelfNo,
          boxNo: boxNo,
        );
        for (final item in items) {
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
      } else {
        // 1. DIRECT INVENTORY SEARCH (Product model name, category, shelf, box, group)
        final directItems = await _repository.searchInventoryDirect(clean);
        for (final item in directItems) {
          if (item.id == null) continue;

          // If location constraint is active, verify item matches location
          if (shelfNo != null && shelfNo.trim().isNotEmpty) {
            if (item.shelfNo.trim().toLowerCase() != shelfNo.trim().toLowerCase()) {
              continue;
            }
          }
          if (boxNo != null && boxNo.trim().isNotEmpty) {
            if (item.boxNo.trim().toLowerCase() != boxNo.trim().toLowerCase()) {
              continue;
            }
          }

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
              if (shelfNo != null && shelfNo.trim().isNotEmpty) {
                if (item.shelfNo.trim().toLowerCase() != shelfNo.trim().toLowerCase()) {
                  continue;
                }
              }
              if (boxNo != null && boxNo.trim().isNotEmpty) {
                if (item.boxNo.trim().toLowerCase() != boxNo.trim().toLowerCase()) {
                  continue;
                }
              }

              resultMap[item.id!] = SearchResultItem(
                item: item,
                alsoFitsModels: compatibleModels,
                matchedPhoneModel: model.phoneName,
              );
            }
          }
        }
      }

      final results = resultMap.values.toList();
      stopwatch.stop();

      DiagnosticService.instance.logInfo(
        'SEARCH',
        'Search for "$clean" (shelf: $shelfNo, box: $boxNo) completed in ${stopwatch.elapsedMilliseconds}ms: ${results.length} inventory items found',
      );

      return results;
    } catch (e, stack) {
      DiagnosticService.instance.logError('SEARCH', 'Search failed for "$clean"', e, stack);
      rethrow;
    }
  }

  Future<List<SearchResultItem>> searchByLocation({
    required String shelfNo,
    String? boxNo,
  }) => search('', shelfNo: shelfNo, boxNo: boxNo);

  // Backwards compatibility alias
  Future<List<SearchResultItem>> searchByPhone(String query) => search(query);
}
