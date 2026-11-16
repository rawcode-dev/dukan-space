import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/inventory_viewmodel.dart';
import 'diagnostics_sheet.dart';
import 'groups_screen.dart';

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
                hintText: 'Filter by model, type, group, shelf, or box...',
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 72,
                          height: 72,
                          errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No inventory items recorded yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w500),
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
    final group = item.accessoryGroupId.trim();

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
                          item.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (group.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            group,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
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
    'Universal Mount / Stand',
    'Custom...',
  ];

  late String _selectedItemType;

  final _modelController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _groupController = TextEditingController();
  final _shelfController = TextEditingController();
  final _boxController = TextEditingController();
  final _stockController = TextEditingController();

  String? _selectedConfirmedGroup;
  int _stockCount = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    // Model name setup
    _modelController.text = item?.modelName ?? '';

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

    // Shelf & Box setup (Custom user inputs)
    _shelfController.text = item?.shelfNo ?? '';
    _boxController.text = item?.boxNo ?? '';

    // Group setup: only set if existing item had one
    if (item != null && item.accessoryGroupId.isNotEmpty) {
      _selectedConfirmedGroup = item.accessoryGroupId;
      _groupController.text = item.accessoryGroupId;
    } else {
      _selectedConfirmedGroup = null;
      _groupController.text = '';
    }

    // Stock count
    _stockCount = item?.stockCount ?? 1;
    _stockController.text = _stockCount.toString();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _customTypeController.dispose();
    _groupController.dispose();
    _shelfController.dispose();
    _boxController.dispose();
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

              // 1. Phone Model / Product Name (Autocomplete or free-form text)
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _modelController.text),
                optionsBuilder: (TextEditingValue textVal) {
                  if (textVal.text.trim().isEmpty) return const Iterable<String>.empty();
                  final query = textVal.text.toLowerCase();
                  return vm.existingModels.where((m) => m.toLowerCase().contains(query)).take(6);
                },
                onSelected: (String selection) {
                  _modelController.text = selection;
                  // If model name changes/selected, remove any previously assigned group
                  if (_selectedConfirmedGroup != null || _groupController.text.isNotEmpty) {
                    _groupController.clear();
                    setState(() {
                      _selectedConfirmedGroup = null;
                    });
                  }
                },
                fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                  controller.addListener(() {
                    if (_modelController.text != controller.text) {
                      _modelController.text = controller.text;
                      // "if name start mismatch group name should be removed"
                      if (_selectedConfirmedGroup != null || _groupController.text.isNotEmpty) {
                        _groupController.clear();
                        setState(() {
                          _selectedConfirmedGroup = null;
                        });
                      }
                    }
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Phone Model / Product Name',
                      hintText: 'e.g. iPhone 13, Redmi Note 12, Type-C Cable...',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please specify model/product' : null,
                    onFieldSubmitted: (v) => onFieldSubmitted(),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 2. Category / Item Type (Dropdown)
              DropdownButtonFormField<String>(
                value: _selectedItemType,
                decoration: InputDecoration(
                  labelText: 'Item Category / Type',
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
                    labelText: 'Enter Custom Category',
                    hintText: 'e.g. Hydrogel Film, Wireless Charger',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please specify category' : null,
                ),
              ],
              const SizedBox(height: 14),

              // 3. Accessory Group ID (OPTIONAL!)
              // "No suggestions before start typing for group"
              // "suggest the group name with typing but user have to click to select the else if not take it as null"
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _selectedConfirmedGroup ?? ''),
                optionsBuilder: (TextEditingValue textVal) {
                  final query = textVal.text.trim().toLowerCase();
                  // No suggestions before user starts typing!
                  if (query.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  // Suggest existing groups as user types
                  return vm.existingGroups.where((g) => g.toLowerCase().contains(query));
                },
                onSelected: (String selection) {
                  // User clicked to select!
                  setState(() {
                    _selectedConfirmedGroup = selection;
                    _groupController.text = selection;
                  });
                },
                fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                  controller.addListener(() {
                    // If user modified text without clicking a suggestion from the list, clear confirmed group
                    if (controller.text.trim() != (_selectedConfirmedGroup ?? '')) {
                      if (_selectedConfirmedGroup != null) {
                        setState(() {
                          _selectedConfirmedGroup = null;
                        });
                      }
                      _groupController.text = '';
                    }
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Accessory Group ID (Optional)',
                      hintText: 'Type to search groups or leave blank',
                      helperText: _selectedConfirmedGroup != null
                          ? '✓ Group selected: $_selectedConfirmedGroup'
                          : 'Optional. Type to search & click to select, or leave empty.',
                      helperStyle: TextStyle(
                        color: _selectedConfirmedGroup != null ? Colors.teal.shade800 : null,
                        fontWeight: _selectedConfirmedGroup != null ? FontWeight.bold : null,
                      ),
                      prefixIcon: const Icon(Icons.tag),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Clear Group',
                              onPressed: () {
                                controller.clear();
                                _groupController.clear();
                                setState(() {
                                  _selectedConfirmedGroup = null;
                                });
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.hub_outlined, size: 20),
                              tooltip: 'Manage Compatibility Groups',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                                );
                              },
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 4. Shelf and Box (Custom direct user input with autocomplete suggestions)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _shelfController.text),
                      optionsBuilder: (TextEditingValue textVal) {
                        if (textVal.text.trim().isEmpty) return const Iterable<String>.empty();
                        final query = textVal.text.toLowerCase();
                        return vm.existingShelves.where((s) => s.toLowerCase().contains(query)).take(5);
                      },
                      onSelected: (String selection) {
                        _shelfController.text = selection;
                      },
                      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(() {
                          _shelfController.text = controller.text;
                        });
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Shelf / Rack Location',
                            hintText: 'e.g. S-1, Rack A, Top Drawer...',
                            prefixIcon: const Icon(Icons.shelves, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          onFieldSubmitted: (v) => onFieldSubmitted(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _boxController.text),
                      optionsBuilder: (TextEditingValue textVal) {
                        if (textVal.text.trim().isEmpty) return const Iterable<String>.empty();
                        final query = textVal.text.toLowerCase();
                        return vm.existingBoxes.where((b) => b.toLowerCase().contains(query)).take(5);
                      },
                      onSelected: (String selection) {
                        _boxController.text = selection;
                      },
                      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(() {
                          _boxController.text = controller.text;
                        });
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Box / Tray / Bin',
                            hintText: 'e.g. B-1, Box 12, Tray 3...',
                            prefixIcon: const Icon(Icons.inbox_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          onFieldSubmitted: (v) => onFieldSubmitted(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Stock Stepper
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
                  backgroundColor: const Color(0xFF0F766E),
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

    // Resolve Model Name
    final finalModel = _modelController.text.trim();

    // Resolve Item Type
    final finalType = _selectedItemType == 'Custom...'
        ? _customTypeController.text.trim()
        : _selectedItemType.trim();

    // Resolve Group ID (Optional - user must click to select, else null/empty)
    final finalGroup = _selectedConfirmedGroup ?? '';

    // Resolve Shelf & Box (Custom direct user inputs)
    final finalShelf = _shelfController.text.trim();
    final finalBox = _boxController.text.trim();

    final finalStock = int.tryParse(_stockController.text.trim()) ?? _stockCount;

    setState(() => _isSaving = true);

    final newItem = InventoryItem(
      id: widget.existingItem?.id,
      modelName: finalModel,
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
          content: Text('Saved: ${newItem.displayName}'),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to save inventory item'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
