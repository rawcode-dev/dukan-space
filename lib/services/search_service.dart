import '../database/inventory_repository.dart';
import '../models/inventory_item.dart';
import '../models/phone_model.dart';
import 'diagnostic_service.dart';

class PhoneSearchResult {
  final PhoneModel matchedModel;
  final List<InventoryItem> accessories;
  final List<String> alsoFitsModels;

  const PhoneSearchResult({
    required this.matchedModel,
    required this.accessories,
    required this.alsoFitsModels,
  });
}

class SearchService {
  final InventoryRepository _repository;

  SearchService({required InventoryRepository repository})
      : _repository = repository;

  Future<List<PhoneSearchResult>> searchByPhone(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final stopwatch = Stopwatch()..start();
    DiagnosticService.instance.logAction('SEARCH', 'Search initiated for model', {'query': clean});

    try {
      // 1. Fetch matching phone models (Indexed LIKE query)
      final matchedModels = await _repository.searchPhoneModels(clean, limit: 10);
      if (matchedModels.isEmpty) {
        DiagnosticService.instance.logWarning('SEARCH', '0 models matched for query "$clean"');
        return [];
      }

      final List<PhoneSearchResult> results = [];

      // 2. Fetch inventory accessories & compatible sibling models
      for (final model in matchedModels) {
        final accessories = await _repository.getInventoryByGroupId(
          model.accessoryGroupId,
        );
        final compatibleModels = await _repository.getCompatibleModelsForGroup(
          model.accessoryGroupId,
          excludeModel: model.phoneName,
        );

        results.add(PhoneSearchResult(
          matchedModel: model,
          accessories: accessories,
          alsoFitsModels: compatibleModels,
        ));
      }

      stopwatch.stop();
      DiagnosticService.instance.logInfo(
        'SEARCH',
        'Search for "$clean" completed in ${stopwatch.elapsedMilliseconds}ms: ${results.length} models, ${results.fold<int>(0, (prev, r) => prev + r.accessories.length)} accessories mapped',
      );

      return results;
    } catch (e, stack) {
      DiagnosticService.instance.logError('SEARCH', 'Search failed for "$clean"', e, stack);
      rethrow;
    }
  }
}
