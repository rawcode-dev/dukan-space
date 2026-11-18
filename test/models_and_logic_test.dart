import 'package:flutter_test/flutter_test.dart';
import 'package:accessory_inventory/models/inventory_item.dart';
import 'package:accessory_inventory/models/location_summary_item.dart';
import 'package:accessory_inventory/models/phone_model.dart';
import 'package:accessory_inventory/models/accessory_group.dart';

void main() {
  group('InventoryItem Model Tests', () {
    test('InventoryItem serialization and deserialization roundtrip', () {
      const item = InventoryItem(
        id: 42,
        modelName: 'iPhone 15 Pro',
        accessoryGroupId: 'GRP-IPHONE-15',
        itemType: 'Tempered Glass',
        shelfNo: 'Shelf 1',
        boxNo: 'Box 2',
        stockCount: 15,
      );

      final map = item.toMap();
      expect(map['id'], 42);
      expect(map['model_name'], 'iPhone 15 Pro');
      expect(map['accessory_group_id'], 'GRP-IPHONE-15');
      expect(map['item_type'], 'Tempered Glass');
      expect(map['shelf_no'], 'Shelf 1');
      expect(map['box_no'], 'Box 2');
      expect(map['stock_count'], 15);

      final fromMapItem = InventoryItem.fromMap(map);
      expect(fromMapItem.id, item.id);
      expect(fromMapItem.modelName, item.modelName);
      expect(fromMapItem.displayName, 'iPhone 15 Pro Tempered Glass');
      expect(fromMapItem.stockCount, 15);
    });

    test('InventoryItem displayName formatting without itemType', () {
      const item = InventoryItem(
        modelName: 'iPhone 14',
        accessoryGroupId: '',
        itemType: '',
        shelfNo: 'S1',
        boxNo: '',
        stockCount: 5,
      );
      expect(item.displayName, 'iPhone 14');
    });

    test('InventoryItem displayName formatting without modelName', () {
      const item = InventoryItem(
        modelName: '',
        accessoryGroupId: '',
        itemType: 'Cleaning Kit',
        shelfNo: 'S1',
        boxNo: '',
        stockCount: 5,
      );
      expect(item.displayName, 'Cleaning Kit');
    });
  });

  group('LocationSummaryItem Tests', () {
    test('Location label formatting with shelf and box', () {
      const loc = LocationSummaryItem(
        shelfNo: 'A1',
        boxNo: 'B2',
        itemCount: 4,
        totalStock: 30,
      );
      expect(loc.locationLabel, 'Shelf: A1 • Box: B2');
      expect(loc.itemCount, 4);
      expect(loc.totalStock, 30);
    });

    test('Location label formatting with only shelf', () {
      const loc = LocationSummaryItem(
        shelfNo: 'Top Shelf',
        boxNo: '',
        itemCount: 2,
        totalStock: 10,
      );
      expect(loc.locationLabel, 'Shelf: Top Shelf');
    });

    test('LocationSummaryItem equality and hash code', () {
      const loc1 = LocationSummaryItem(shelfNo: '1', boxNo: 'A', itemCount: 1, totalStock: 5);
      const loc2 = LocationSummaryItem(shelfNo: '1', boxNo: 'A', itemCount: 99, totalStock: 999);
      expect(loc1, equals(loc2));
      expect(loc1.hashCode, equals(loc2.hashCode));
    });
  });

  group('PhoneModel Model Tests', () {
    test('PhoneModel serialization and deserialization', () {
      const model = PhoneModel(
        phoneName: 'Samsung Galaxy S24',
        accessoryGroupId: 'GRP-SAM-S24',
      );

      final map = model.toMap();
      expect(map['phone_name'], 'Samsung Galaxy S24');
      expect(map['accessory_group_id'], 'GRP-SAM-S24');

      final fromMapModel = PhoneModel.fromMap(map);
      expect(fromMapModel.phoneName, 'Samsung Galaxy S24');
      expect(fromMapModel.accessoryGroupId, 'GRP-SAM-S24');
    });
  });

  group('AccessoryGroup Tests', () {
    test('AccessoryGroup properties and formatting', () {
      const group = AccessoryGroup(
        groupId: 'GRP-IPHONE-13-14',
        phoneModels: ['iPhone 13', 'iPhone 14'],
        inventoryItemCount: 3,
        totalStockCount: 25,
      );

      expect(group.groupId, 'GRP-IPHONE-13-14');
      expect(group.phoneModels.length, 2);
      expect(group.phoneModels.join(', '), 'iPhone 13, iPhone 14');
      expect(group.totalStockCount, 25);
    });
  });

  group('Search Tokenization Logic Tests', () {
    test('Multi-token splitting for shelf and box searches', () {
      const query = 'Shelf 1 Box 2';
      final tokens = query.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      expect(tokens, ['shelf', '1', 'box', '2']);
      expect(tokens.length, 4);
    });

    test('Single token query handling', () {
      const query = 'iPhone';
      final tokens = query.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      expect(tokens, ['iphone']);
      expect(tokens.length, 1);
    });
  });
}
