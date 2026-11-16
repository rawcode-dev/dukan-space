class InventoryItem {
  final int? id;
  final String modelName; // Target phone model or product title (e.g. "iPhone 13", "Redmi Note 12", "Universal")
  final String accessoryGroupId; // Optional Group ID (can be empty string if unmapped)
  final String itemType; // Category: Tempered Glass, Back Cover, Cable, Charger, etc.
  final String shelfNo;
  final String boxNo;
  final int stockCount;

  const InventoryItem({
    this.id,
    this.modelName = '',
    this.accessoryGroupId = '',
    required this.itemType,
    required this.shelfNo,
    this.boxNo = '',
    required this.stockCount,
  });

  String get displayName {
    final cleanModel = modelName.trim();
    final cleanType = itemType.trim();
    if (cleanModel.isEmpty) return cleanType.isEmpty ? 'General Item' : cleanType;
    if (cleanType.isEmpty) return cleanModel;
    if (cleanModel.toLowerCase().contains(cleanType.toLowerCase())) return cleanModel;
    return '$cleanModel $cleanType';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'model_name': modelName.trim(),
      'accessory_group_id': accessoryGroupId.trim(),
      'item_type': itemType.trim(),
      'shelf_no': shelfNo.trim(),
      'box_no': boxNo.trim(),
      'stock_count': stockCount,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      modelName: (map['model_name'] as String?) ?? '',
      accessoryGroupId: (map['accessory_group_id'] as String?) ?? '',
      itemType: (map['item_type'] as String?) ?? '',
      shelfNo: (map['shelf_no'] as String?) ?? '',
      boxNo: (map['box_no'] as String?) ?? '',
      stockCount: (map['stock_count'] as int?) ?? 0,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? modelName,
    String? accessoryGroupId,
    String? itemType,
    String? shelfNo,
    String? boxNo,
    int? stockCount,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      accessoryGroupId: accessoryGroupId ?? this.accessoryGroupId,
      itemType: itemType ?? this.itemType,
      shelfNo: shelfNo ?? this.shelfNo,
      boxNo: boxNo ?? this.boxNo,
      stockCount: stockCount ?? this.stockCount,
    );
  }
}
