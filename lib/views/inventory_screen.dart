import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../viewmodels/inventory_viewmodel.dart';
import 'diagnostics_sheet.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Break Logs & Diagnostics',
            onPressed: () => DiagnosticsSheet.show(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter by group, type, shelf, or box...',
                prefixIcon: const Icon(Icons.filter_list, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: vm.filterInventory,
            ),
          ),
        ),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No inventory items recorded yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "+ Add Item" below to add stock.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: vm.items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final item = vm.items[index];
                    return _buildInventoryCard(context, item, vm);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    InventoryItem item,
    InventoryViewModel vm,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.accessoryGroupId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shelf: ${item.shelfNo}   •   Box: ${item.boxNo}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => vm.adjustStock(item.id!, -1),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.stockCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => vm.adjustStock(item.id!, 1),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openItemDialog(context, item: item);
                    } else if (value == 'delete') {
                      vm.deleteItem(item.id!);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openItemDialog(BuildContext context, {InventoryItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AddEditItemSheet(existingItem: item, parentContext: context);
      },
    );
  }
}

class _AddEditItemSheet extends StatefulWidget {
  final InventoryItem? existingItem;
  final BuildContext parentContext;

  const _AddEditItemSheet({
    this.existingItem,
    required this.parentContext,
  });

  @override
  State<_AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<_AddEditItemSheet> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _predefinedItemTypes = [
    'Tempered Glass',
    'Back Cover / Case',
    'Camera Lens Protector',
    'UV Curved Glass',
    'Privacy Screen Guard',
    'Matte Screen Guard',
    'Skin / Wrap',
    'Charging Cable',
    'Charging Adapter',
    'Earphones / TWS',
    'Custom...',
  ];

  static const List<String> _predefinedShelves = [
    'S-01', 'S-02', 'S-03', 'S-04', 'S-05', 'S-06', 'S-07', 'S-08', 'Custom...',
  ];

  static const List<String> _predefinedBoxes = [
    'B-01', 'B-02', 'B-03', 'B-04', 'B-05', 'B-06', 'B-07', 'B-08', 'Custom...',
  ];

  late String _selectedItemType;
  late String _selectedShelf;
  late String _selectedBox;
  String? _selectedGroup;

  final _customTypeController = TextEditingController();
  final _customGroupController = TextEditingController();
  final _customShelfController = TextEditingController();
  final _customBoxController = TextEditingController();
  final _stockController = TextEditingController();

  int _stockCount = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    // Item Type setup
    if (item != null && item.itemType.isNotEmpty) {
      if (_predefinedItemTypes.contains(item.itemType)) {
        _selectedItemType = item.itemType;
      } else {
        _selectedItemType = 'Custom...';
        _customTypeController.text = item.itemType;
      }
    } else {
      _selectedItemType = _predefinedItemTypes.first;
    }

    // Shelf setup
    if (item != null && item.shelfNo.isNotEmpty) {
      if (_predefinedShelves.contains(item.shelfNo)) {
        _selectedShelf = item.shelfNo;
      } else {
        _selectedShelf = 'Custom...';
        _customShelfController.text = item.shelfNo;
      }
    } else {
      _selectedShelf = _predefinedShelves.first;
    }

    // Box setup
    if (item != null && item.boxNo.isNotEmpty) {
      if (_predefinedBoxes.contains(item.boxNo)) {
        _selectedBox = item.boxNo;
      } else {
        _selectedBox = 'Custom...';
        _customBoxController.text = item.boxNo;
      }
    } else {
      _selectedBox = _predefinedBoxes.first;
    }

    // Group setup
    if (item != null && item.accessoryGroupId.isNotEmpty) {
      _selectedGroup = item.accessoryGroupId;
      _customGroupController.text = item.accessoryGroupId;
    }

    // Stock count
    _stockCount = item?.stockCount ?? 1;
    _stockController.text = _stockCount.toString();
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _customGroupController.dispose();
    _customShelfController.dispose();
    _customBoxController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _updateStock(int delta) {
    setState(() {
      _stockCount = (_stockCount + delta).clamp(0, 999999);
      _stockController.text = _stockCount.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.parentContext.watch<InventoryViewModel>();
    final theme = Theme.of(context);

    // Build available group choices
    final groupOptions = <String>{...vm.existingGroups};
    if (widget.existingItem != null && widget.existingItem!.accessoryGroupId.isNotEmpty) {
      groupOptions.add(widget.existingItem!.accessoryGroupId);
    }
    final List<String> groupList = groupOptions.toList()..sort();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingItem == null ? 'Add Inventory Item' : 'Edit Inventory Item',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Item Type (Dropdown)
              DropdownButtonFormField<String>(
                value: _selectedItemType,
                decoration: InputDecoration(
                  labelText: 'Item Type',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: _predefinedItemTypes.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedItemType = val);
                },
              ),
              if (_selectedItemType == 'Custom...') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customTypeController,
                  decoration: InputDecoration(
                    labelText: 'Enter Custom Item Type',
                    hintText: 'e.g. Hydrogel Screen Guard',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please specify item type' : null,
                ),
              ],
              const SizedBox(height: 14),

              // 2. Accessory Group ID (Dropdown if groups exist, else text input)
              if (groupList.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedGroup != null && groupList.contains(_selectedGroup)
                      ? _selectedGroup
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Accessory Group ID',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    helperText: 'Links phone models that share this accessory size',
                  ),
                  hint: const Text('Select existing group or create new'),
                  items: [
                    ...groupList.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                    const DropdownMenuItem(value: '__NEW__', child: Text('+ Enter New Group ID...')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == '__NEW__') {
                        _selectedGroup = '__NEW__';
                      } else {
                        _selectedGroup = val;
                      }
                    });
                  },
                  validator: (v) {
                    if (_selectedGroup == null) return 'Please choose or enter a Group ID';
                    return null;
                  },
                ),
                if (_selectedGroup == '__NEW__') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customGroupController,
                    decoration: InputDecoration(
                      labelText: 'New Group ID',
                      hintText: 'e.g. GRP-IP14 or GRP-RN12',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ] else ...[
                TextFormField(
                  controller: _customGroupController,
                  decoration: InputDecoration(
                    labelText: 'Accessory Group ID (e.g. GRP-A)',
                    prefixIcon: const Icon(Icons.tag),
                    hintText: 'e.g. GRP-RN12',
                    helperText: 'Links phone models sharing this group to this stock',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 14),

              // 3. Shelf and Box (Dropdowns with Custom option)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedShelf,
                          decoration: InputDecoration(
                            labelText: 'Shelf No.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: {
                            ..._predefinedShelves,
                            ...vm.existingShelves,
                            'Custom...',
                          }.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedShelf = val);
                          },
                        ),
                        if (_selectedShelf == 'Custom...') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customShelfController,
                            decoration: InputDecoration(
                              labelText: 'Custom Shelf',
                              hintText: 'e.g. S-99',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedBox,
                          decoration: InputDecoration(
                            labelText: 'Box No.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: {
                            ..._predefinedBoxes,
                            ...vm.existingBoxes,
                            'Custom...',
                          }.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBox = val);
                          },
                        ),
                        if (_selectedBox == 'Custom...') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customBoxController,
                            decoration: InputDecoration(
                              labelText: 'Custom Box',
                              hintText: 'e.g. B-99',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Stock Stepper with +/- buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Stock Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () => _updateStock(-1),
                    ),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        controller: _stockController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: const InputDecoration(border: InputBorder.none),
                        onChanged: (v) {
                          final val = int.tryParse(v);
                          if (val != null) _stockCount = val;
                        },
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _updateStock(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save Action Button
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveRecord,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving...' : 'Save Record'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve Item Type
    final finalType = _selectedItemType == 'Custom...'
        ? _customTypeController.text.trim()
        : _selectedItemType.trim();

    // Resolve Group ID
    String finalGroup;
    if (_selectedGroup == '__NEW__' || _selectedGroup == null) {
      finalGroup = _customGroupController.text.trim();
    } else {
      finalGroup = _selectedGroup!.trim();
    }

    // Resolve Shelf
    final finalShelf = _selectedShelf == 'Custom...'
        ? _customShelfController.text.trim()
        : _selectedShelf.trim();

    // Resolve Box
    final finalBox = _selectedBox == 'Custom...'
        ? _customBoxController.text.trim()
        : _selectedBox.trim();

    final finalStock = int.tryParse(_stockController.text.trim()) ?? _stockCount;

    setState(() => _isSaving = true);

    final newItem = InventoryItem(
      id: widget.existingItem?.id,
      accessoryGroupId: finalGroup,
      itemType: finalType,
      shelfNo: finalShelf,
      boxNo: finalBox,
      stockCount: finalStock,
    );

    final vm = widget.parentContext.read<InventoryViewModel>();
    final success = await vm.saveOrUpdateItem(newItem);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text('Saved: $finalType ($finalGroup)'),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to save item to database'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
