import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/search_service.dart';
import '../viewmodels/search_viewmodel.dart';
import 'diagnostics_sheet.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  void _openLocationInspector(BuildContext context) {
    final vm = context.read<SearchViewModel>();
    vm.loadLocationMetadata();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _LocationInspectorSheet(searchViewModel: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Compatibility Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Break Logs & Diagnostics',
            onPressed: () => DiagnosticsSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: 'Search phone, item, shelf, or box (e.g. Shelf 1 Box 2)...',
              leading: const Icon(Icons.search),
              trailing: vm.searchQuery.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: vm.clearSearch,
                      )
                    ]
                  : null,
              onChanged: vm.onQueryChanged,
              onSubmitted: (_) => vm.executeSearch(),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // Location Filter Chip Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                if (!vm.isLocationFilterActive) ...[
                  ActionChip(
                    avatar: const Icon(Icons.shelves, size: 16),
                    label: const Text('Find by Shelf & Box'),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => _openLocationInspector(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tip: Or type "Shelf 1 Box 2"',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '📍 ${vm.locationFilterLabel}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => _openLocationInspector(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: vm.clearLocationFilter,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (vm.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),

          Expanded(
            child: _buildResultsList(context, vm),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, SearchViewModel vm) {
    if (vm.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                vm.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (vm.searchQuery.isEmpty && !vm.isLocationFilterActive) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (_, __, ___) => Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Search Inventory, Shelves & Boxes',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Type any phone model, accessory name, or physical shelf & box number.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _openLocationInspector(context),
                icon: const Icon(Icons.shelves, size: 18),
                label: const Text('Find by Shelf & Box'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade800),
                        const SizedBox(width: 6),
                        Text(
                          'Quick Search Examples:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• "Shelf 1 Box 2" -> View items in that specific box\n'
                      '• "Box 5" -> All items across store located in Box 5\n'
                      '• "iPhone 14 Case" -> Searches models & checks cross-compatibility',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.results.isEmpty && !vm.isLoading) {
      final label = vm.isLocationFilterActive
          ? (vm.searchQuery.isNotEmpty
              ? '"${vm.searchQuery}" in ${vm.locationFilterLabel}'
              : vm.locationFilterLabel)
          : '"${vm.searchQuery}"';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No items found for $label',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check shelf and box spelling or add inventory in the "Inventory" tab.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (vm.isLocationFilterActive) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: vm.clearLocationFilter,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear Location Filter'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.isLocationFilterActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              'Showing ${vm.results.length} product(s) stored in ${vm.locationFilterLabel}:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: vm.results.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final result = vm.results[index];
              return _buildInventoryResultCard(context, result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryResultCard(BuildContext context, SearchResultItem result) {
    final theme = Theme.of(context);
    final item = result.item;
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (group.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Group: $group',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueGrey.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        item.boxNo.trim().isNotEmpty
                            ? 'Shelf: ${item.shelfNo}   •   Box: ${item.boxNo}'
                            : 'Shelf: ${item.shelfNo}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.stockCount > 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Stock: ${item.stockCount}',
                    style: TextStyle(
                      color: item.stockCount > 0 ? Colors.green.shade900 : Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (result.alsoFitsModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Also fits ${result.alsoFitsModels.length} models:',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.alsoFitsModels.map((otherModel) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      otherModel,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationInspectorSheet extends StatefulWidget {
  final SearchViewModel searchViewModel;

  const _LocationInspectorSheet({required this.searchViewModel});

  @override
  State<_LocationInspectorSheet> createState() => _LocationInspectorSheetState();
}

class _LocationInspectorSheetState extends State<_LocationInspectorSheet> {
  String? _tempShelf;
  String? _tempBox;
  final TextEditingController _shelfCtrl = TextEditingController();
  final TextEditingController _boxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempShelf = widget.searchViewModel.selectedShelf;
    _tempBox = widget.searchViewModel.selectedBox;
    _shelfCtrl.text = _tempShelf ?? '';
    _boxCtrl.text = _tempBox ?? '';
  }

  @override
  void dispose() {
    _shelfCtrl.dispose();
    _boxCtrl.dispose();
    super.dispose();
  }

  void _applyAndClose(String? shelf, String? box) {
    widget.searchViewModel.applyLocationFilter(
      shelf: shelf,
      box: box,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = widget.searchViewModel;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.shelves, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shop Location Inspector',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Inspect what is stored inside any shelf or box',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Manual Shelf / Box Filter input
                    Text(
                      'Filter by Specific Shelf & Box',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _shelfCtrl,
                            decoration: InputDecoration(
                              labelText: 'Shelf (e.g. 1, A, Top)',
                              prefixIcon: const Icon(Icons.shelves, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              _tempShelf = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _boxCtrl,
                            decoration: InputDecoration(
                              labelText: 'Box (e.g. 2, Red, B1)',
                              prefixIcon: const Icon(Icons.all_inbox, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              _tempBox = val;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        _applyAndClose(_shelfCtrl.text.trim(), _boxCtrl.text.trim());
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Show Products in This Location'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Overview of existing storage locations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Store Locations Overview',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (vm.locationSummaries.isNotEmpty)
                          Text(
                            '${vm.locationSummaries.length} location(s)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap any shelf & box below to immediately view all products stored inside:',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    if (vm.isLoadingLocations)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (vm.locationSummaries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No shelf/box locations recorded yet. Add inventory items with shelf and box numbers to browse them here.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...vm.locationSummaries.map((loc) {
                        final isSelected =
                            vm.selectedShelf?.trim().toLowerCase() == loc.shelfNo.trim().toLowerCase() &&
                            vm.selectedBox?.trim().toLowerCase() == loc.boxNo.trim().toLowerCase();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withOpacity(0.5),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _applyAndClose(loc.shelfNo, loc.boxNo),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.all_inbox,
                                size: 20,
                                color: isSelected ? Colors.white : Colors.blueGrey,
                              ),
                            ),
                            title: Text(
                              loc.locationLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${loc.itemCount} distinct product(s) • Total stock: ${loc.totalStock}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
