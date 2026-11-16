import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/accessory_group.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/inventory_viewmodel.dart';
import 'diagnostics_sheet.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedGroups = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openGroupEditor(BuildContext context, {AccessoryGroup? existingGroup}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroupEditorSheet(existingGroup: existingGroup),
    );
  }

  void _showQuickAddModelDialog(BuildContext context, AccessoryGroup group) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Model to ${group.groupId}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Phone Model Name',
            hintText: 'e.g. iPhone 14 Plus',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(ctx).pop();
              context.read<GroupViewModel>().addModelToGroup(group.groupId, text);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop();
                context.read<GroupViewModel>().addModelToGroup(group.groupId, text);
              }
            },
            child: const Text('Add Model'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, AccessoryGroup group) {
    bool clearFromInventory = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Group "${group.groupId}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will unlink ${group.phoneModels.length} phone models from this group.',
                style: const TextStyle(fontSize: 14),
              ),
              if (group.inventoryItemCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${group.inventoryItemCount} stock item(s) are currently tagged with this group.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: clearFromInventory,
                  title: const Text('Clear group from stock items', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Keeps items as standalone without group', style: TextStyle(fontSize: 11)),
                  onChanged: (val) {
                    setDialogState(() {
                      clearFromInventory = val ?? true;
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final groupVm = context.read<GroupViewModel>();
                final invVm = context.read<InventoryViewModel>();
                final success = await groupVm.deleteGroup(
                  group.groupId,
                  clearFromInventory: clearFromInventory,
                );
                if (success && clearFromInventory) {
                  invVm.loadInventory();
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compatibility Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Groups',
            onPressed: vm.loadGroups,
          ),
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter by group ID or phone model...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          vm.filterGroups('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: vm.filterGroups,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGroupEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.loadGroups,
              child: vm.groups.isEmpty
                  ? _buildEmptyState(context, vm)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: vm.groups.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSummaryHeader(context, vm);
                        }
                        final group = vm.groups[index - 1];
                        return _buildGroupCard(context, group);
                      },
                    ),
            ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, GroupViewModel vm) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vm.totalGroupCount} Compatibility Groups',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vm.totalMappedModels} Phone models cross-linked for instant compatibility',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, GroupViewModel vm) {
    final hasSearch = vm.searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 72,
                height: 72,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.hub_outlined, size: 64, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No groups matching "${vm.searchQuery}"'
                  : 'No Compatibility Groups Yet',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try searching by a different group ID or model name.'
                  : 'Create groups manually so accessories (tempered glass, covers) automatically match compatible phone models.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openGroupEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Create New Group'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, AccessoryGroup group) {
    final theme = Theme.of(context);
    final isExpanded = _expandedGroups.contains(group.groupId);
    final models = group.phoneModels;
    final displayModels = isExpanded || models.length <= 4
        ? models
        : models.take(3).toList();
    final remainingCount = models.length - displayModels.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Group ID + badges + actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub, size: 14, color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        group.groupId,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (group.inventoryItemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      '${group.totalStockCount} stock (${group.inventoryItemCount} items)',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Group',
                  onPressed: () => _openGroupEditor(context, existingGroup: group),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete Group',
                  color: theme.colorScheme.error,
                  onPressed: () => _confirmDeleteGroup(context, group),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Models section
            if (models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'No phone models linked yet (used as standalone inventory tag)',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...displayModels.map((m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )),
                  if (remainingCount > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _expandedGroups.add(group.groupId);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$remainingCount more',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isExpanded && models.length > 4)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _expandedGroups.remove(group.groupId);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Show less',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 10),
            // Quick action to add model
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showQuickAddModelDialog(context, group),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Add Phone Model', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupEditorSheet extends StatefulWidget {
  final AccessoryGroup? existingGroup;

  const _GroupEditorSheet({this.existingGroup});

  @override
  State<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends State<_GroupEditorSheet> {
  final _groupIdController = TextEditingController();
  final _modelInputController = TextEditingController();
  final List<String> _models = [];
  bool _updateInventory = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingGroup != null) {
      _groupIdController.text = widget.existingGroup!.groupId;
      _models.addAll(widget.existingGroup!.phoneModels);
    }
  }

  @override
  void dispose() {
    _groupIdController.dispose();
    _modelInputController.dispose();
    super.dispose();
  }

  void _addModelFromInput() {
    final raw = _modelInputController.text.trim();
    if (raw.isEmpty) return;

    // Support comma or newline delimited pasting
    final parts = raw.split(RegExp(r'[,;\n]'));
    setState(() {
      for (final p in parts) {
        final clean = p.trim();
        if (clean.isNotEmpty && !_models.any((m) => m.toLowerCase() == clean.toLowerCase())) {
          _models.add(clean);
        }
      }
      _modelInputController.clear();
      _error = null;
    });
  }

  void _removeModel(String model) {
    setState(() {
      _models.removeWhere((m) => m.toLowerCase() == model.toLowerCase());
    });
  }

  Future<void> _handleSave() async {
    final rawGid = _groupIdController.text.trim();

    // Include any text currently in the model input if user didn't press Add
    if (_modelInputController.text.trim().isNotEmpty) {
      _addModelFromInput();
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final groupVm = context.read<GroupViewModel>();
    final invVm = context.read<InventoryViewModel>();

    final savedGid = await groupVm.saveGroup(
      oldGroupId: widget.existingGroup?.groupId,
      newGroupId: rawGid,
      phoneModels: _models,
      updateInventory: _updateInventory,
    );

    if (!mounted) return;

    if (savedGid != null) {
      // Refresh inventory VM so autocomplete and filters update
      invVm.loadInventory();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingGroup != null
                ? 'Group "$savedGid" updated successfully'
                : 'Group "$savedGid" created successfully with ${_models.length} model(s)',
          ),
          backgroundColor: Colors.teal.shade800,
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _error = groupVm.errorMessage ?? 'Failed to save group.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingGroup != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hub, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Compatibility Group' : 'Create New Group',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Map multiple phone models that share the same accessories',
                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
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

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Group ID field (Optional - auto-generated if left empty)
                  TextField(
                    controller: _groupIdController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Group ID / Tag (Optional)',
                      hintText: 'e.g. GRP-IP14 (Leave empty for auto-name)',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      helperText: 'Optional. Leave blank to auto-generate a unique group name.',
                    ),
                  ),

                  if (isEditing && (widget.existingGroup?.inventoryItemCount ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _updateInventory,
                      title: const Text('Update existing inventory items with this group', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        'Syncs ${widget.existingGroup!.inventoryItemCount} stock item(s) if group name changes',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _updateInventory = val ?? true;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Phone models heading
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Compatible Phone Models (${_models.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_models.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _models.clear();
                            });
                          },
                          child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Add Model Input Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _modelInputController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Add Phone Model',
                            hintText: 'e.g. iPhone 13, iPhone 14',
                            prefixIcon: const Icon(Icons.phone_android),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            helperText: 'You can type single or paste comma-separated models',
                          ),
                          onSubmitted: (_) => _addModelFromInput(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _addModelFromInput,
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 4),
                            Text('Add'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tag List of Added Models
                  if (_models.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Text(
                        'No phone models added yet. Add at least one phone model to enable automatic compatibility matching.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _models.map((model) {
                        return Chip(
                          label: Text(model, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          avatar: const Icon(Icons.phone_android, size: 16),
                          deleteIcon: const Icon(Icons.cancel, size: 16),
                          onDeleted: () => _removeModel(model),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  // Save button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isSaving
                          ? 'Saving Group...'
                          : isEditing
                              ? 'Update Group'
                              : 'Create Group',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

