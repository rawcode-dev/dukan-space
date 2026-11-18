class LocationSummaryItem {
  final String shelfNo;
  final String boxNo;
  final int itemCount;
  final int totalStock;

  const LocationSummaryItem({
    required this.shelfNo,
    required this.boxNo,
    required this.itemCount,
    required this.totalStock,
  });

  String get locationLabel {
    if (boxNo.trim().isNotEmpty) {
      return 'Shelf: $shelfNo • Box: $boxNo';
    }
    return 'Shelf: $shelfNo';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSummaryItem &&
          runtimeType == other.runtimeType &&
          shelfNo == other.shelfNo &&
          boxNo == other.boxNo;

  @override
  int get hashCode => shelfNo.hashCode ^ boxNo.hashCode;
}
