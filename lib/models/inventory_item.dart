class InventoryItem {
  final int? id;
  final String accessoryGroupId;
  final String itemType;
  final String shelfNo;
  final String boxNo;
  final int stockCount;

  const InventoryItem({
    this.id,
    required this.accessoryGroupId,
    required this.itemType,
    required this.shelfNo,
    required this.boxNo,
    required this.stockCount,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
      accessoryGroupId: (map['accessory_group_id'] as String?) ?? '',
      itemType: (map['item_type'] as String?) ?? '',
      shelfNo: (map['shelf_no'] as String?) ?? '',
      boxNo: (map['box_no'] as String?) ?? '',
      stockCount: (map['stock_count'] as int?) ?? 0,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? accessoryGroupId,
    String? itemType,
    String? shelfNo,
    String? boxNo,
    int? stockCount,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      accessoryGroupId: accessoryGroupId ?? this.accessoryGroupId,
      itemType: itemType ?? this.itemType,
      shelfNo: shelfNo ?? this.shelfNo,
      boxNo: boxNo ?? this.boxNo,
      stockCount: stockCount ?? this.stockCount,
    );
  }
}

