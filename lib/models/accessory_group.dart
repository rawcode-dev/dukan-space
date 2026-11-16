class AccessoryGroup {
  final String groupId;
  final List<String> phoneModels;
  final int inventoryItemCount;
  final int totalStockCount;

  const AccessoryGroup({
    required this.groupId,
    this.phoneModels = const [],
    this.inventoryItemCount = 0,
    this.totalStockCount = 0,
  });

  AccessoryGroup copyWith({
    String? groupId,
    List<String>? phoneModels,
    int? inventoryItemCount,
    int? totalStockCount,
  }) {
    return AccessoryGroup(
      groupId: groupId ?? this.groupId,
      phoneModels: phoneModels ?? this.phoneModels,
      inventoryItemCount: inventoryItemCount ?? this.inventoryItemCount,
      totalStockCount: totalStockCount ?? this.totalStockCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessoryGroup &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId;

  @override
  int get hashCode => groupId.hashCode;
}

