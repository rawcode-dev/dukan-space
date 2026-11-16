import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/diagnostic_service.dart';
import '../viewmodels/inventory_viewmodel.dart';

class DiagnosticsSheet extends StatefulWidget {
  const DiagnosticsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DiagnosticsSheet(),
    );
  }

  @override
  State<DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<DiagnosticsSheet> {
  bool _isSharing = false;
  String _cachedLogText = 'Loading logs...';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final invVm = context.read<InventoryViewModel>();
      final report = await DiagnosticService.instance.generateDiagnosticReport(dbStats: invVm.stats);
      if (mounted) {
        setState(() {
          _cachedLogText = report;
        });
      }
    } catch (_) {
      final text = await DiagnosticService.instance.getFullLogText();
      if (mounted) {
        setState(() {
          _cachedLogText = text.isEmpty ? 'No diagnostic logs recorded yet.' : text;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invVm = context.watch<InventoryViewModel>();
    final stats = invVm.stats;

    final recentLogs = DiagnosticService.instance.recentLogs;
    final errorCount = recentLogs.where((l) => l.level == 'ERROR').length;
    final warnCount = recentLogs.where((l) => l.level == 'WARN').length;

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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bug_report, color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diagnostics & Break Logs',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Share with developers via Bluetooth, WhatsApp or Email',
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

          // Health / Status Badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildStatusPill(
                  label: 'Errors: $errorCount',
                  color: errorCount > 0 ? Colors.red : Colors.green,
                  icon: errorCount > 0 ? Icons.error_outline : Icons.check_circle_outline,
                ),
                const SizedBox(width: 8),
                _buildStatusPill(
                  label: 'Warnings: $warnCount',
                  color: warnCount > 0 ? Colors.orange : Colors.grey,
                  icon: Icons.warning_amber_outlined,
                ),
                const SizedBox(width: 8),
                _buildStatusPill(
                  label: 'Models: ${stats['models'] ?? 0}',
                  color: Colors.blue,
                  icon: Icons.phone_android,
                ),
              ],
            ),
          ),

          // Log terminal display
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  _cachedLogText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF86EFAC), // Soft green terminal text
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _isSharing
                      ? null
                      : () async {
                          setState(() => _isSharing = true);
                          await DiagnosticService.instance.shareLogs(dbStats: stats);
                          if (mounted) setState(() => _isSharing = false);
                        },
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share),
                  label: const Text('Share Logs (Bluetooth, WhatsApp, Mail, Wi-Fi)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _cachedLogText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logs copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy Logs'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await DiagnosticService.instance.clearLogs();
                          await _loadLogs();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logs cleared'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Clear Logs', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

