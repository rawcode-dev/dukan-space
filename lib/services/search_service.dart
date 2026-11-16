import '../database/inventory_repository.dart';
import '../models/inventory_item.dart';
import '../models/phone_model.dart';

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

    // 1. Fetch matching phone models (Indexed LIKE query)
    final matchedModels = await _repository.searchPhoneModels(clean, limit: 10);
    if (matchedModels.isEmpty) return [];

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

    return results;
  }
}

