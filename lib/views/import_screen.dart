import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/import_viewmodel.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImportViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Catalog'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ensure your Excel sheet (.xlsx/.xls) has:\n'
                      '• Column A: Phone Model Name\n'
                      '• Column B: Accessory Group ID',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: vm.isProcessing ? null : vm.pickAndParseExcel,
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(
                vm.selectedFileName != null ? 'Change: ${vm.selectedFileName}' : 'Select Excel File',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            if (vm.isProcessing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (vm.statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vm.statusMessage!,
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            if (vm.parsedResult != null && vm.parsedResult!.phoneModels.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parsed Summary',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('• Total Records: ${vm.parsedResult!.phoneModels.length}'),
                      Text('• Skipped Rows: ${vm.parsedResult!.skippedRows}'),
                      const SizedBox(height: 16),
                      Text(
                        'Choose Import Strategy:',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: vm.isProcessing
                                  ? null
                                  : () => _confirmAction(context, vm, ImportMode.merge),
                              child: const Text('Merge (Upsert)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: vm.isProcessing
                                  ? null
                                  : () => _confirmAction(context, vm, ImportMode.replace),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                              child: const Text('Replace All'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, ImportViewModel vm, ImportMode mode) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(mode == ImportMode.replace ? 'Replace All Models?' : 'Merge Records?'),
          content: Text(
            mode == ImportMode.replace
                ? 'This will ERASE all current phone models and replace them with the parsed Excel catalog.'
                : 'This will update existing models and insert new ones without deleting unmatched records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                vm.commitImport(mode);
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }
}

