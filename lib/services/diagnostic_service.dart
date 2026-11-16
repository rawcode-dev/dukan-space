import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_provider.dart';

class DiagnosticLogEntry {
  final DateTime timestamp;
  final String level; // INFO, ACTION, WARN, ERROR
  final String tag;
  final String message;
  final String? errorDetails;

  DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.errorDetails,
  });

  String toFormattedString() {
    final timeStr = timestamp.toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    final dateStr = timestamp.toIso8601String().substring(0, 10); // YYYY-MM-DD
    final buffer = StringBuffer('[$dateStr $timeStr] [$level] [$tag] $message');
    if (errorDetails != null && errorDetails!.isNotEmpty) {
      buffer.write('\n    ↳ Stack/Details: $errorDetails');
    }
    return buffer.toString();
  }
}

class DiagnosticService {
  DiagnosticService._internal();
  static final DiagnosticService instance = DiagnosticService._internal();

  static const String _logFileName = 'dukan_diagnostics.log';
  static const int _maxInMemoryEntries = 250;
  static const int _maxFileSizeBytes = 1024 * 1024; // 1 MB max on disk

  final List<DiagnosticLogEntry> _memoryBuffer = [];
  File? _logFile;
  bool _isInitialized = false;

  List<DiagnosticLogEntry> get recentLogs => List.unmodifiable(_memoryBuffer);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File(join(dir.path, _logFileName));
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
        await _logFile!.writeAsString('--- DukanSpace Diagnostics Started ---\n');
      }
      _isInitialized = true;
      logInfo('SYSTEM', 'Diagnostic logger initialized. App starting.');
    } catch (e) {
      debugPrint('Failed to initialize DiagnosticService file: $e');
    }
  }

  void logInfo(String tag, String message) {
    _record('INFO', tag, message);
  }

  void logAction(String tag, String action, [Map<String, dynamic>? params]) {
    final paramStr = params != null && params.isNotEmpty ? ' | Data: $params' : '';
    _record('ACTION', tag, '$action$paramStr');
  }

  void logWarning(String tag, String message) {
    _record('WARN', tag, message);
  }

  void logError(String tag, String message, [dynamic error, StackTrace? stack]) {
    final buffer = StringBuffer();
    if (error != null) {
      buffer.write(error.toString());
    }
    if (stack != null) {
      buffer.write('\n$stack');
    }
    final details = buffer.toString().trim();
    _record('ERROR', tag, message, details.isEmpty ? null : details);
  }

  void _record(String level, String tag, String message, [String? errorDetails]) {
    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      errorDetails: errorDetails,
    );

    // Maintain in-memory circular buffer for quick UI inspection
    if (_memoryBuffer.length >= _maxInMemoryEntries) {
      _memoryBuffer.removeAt(0);
    }
    _memoryBuffer.add(entry);

    debugPrint(entry.toFormattedString());

    // Asynchronously append to persistent file
    _appendToFile(entry);
  }

  Future<void> _appendToFile(DiagnosticLogEntry entry) async {
    if (_logFile == null) return;
    try {
      if (await _logFile!.exists()) {
        final length = await _logFile!.length();
        if (length > _maxFileSizeBytes) {
          await _logFile!.writeAsString('--- Log Truncated Due to 1MB Limit ---\n');
        }
      }
      await _logFile!.writeAsString(
        '${entry.toFormattedString()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('Diagnostic file write error: $e');
    }
  }

  Future<String> getFullLogText() async {
    if (_logFile != null && await _logFile!.exists()) {
      try {
        final content = await _logFile!.readAsString();
        if (content.trim().isNotEmpty) return content;
      } catch (_) {}
    }
    return _memoryBuffer.map((e) => e.toFormattedString()).join('\n');
  }

  Future<void> clearLogs() async {
    _memoryBuffer.clear();
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('--- DukanSpace Diagnostics Reset ---\n');
      }
    } catch (_) {}
    logInfo('SYSTEM', 'Diagnostics logs cleared by user');
  }

  Future<String> generateDiagnosticReport({Map<String, int>? dbStats}) async {
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer();

    buffer.writeln('############################################################');
    buffer.writeln('#             DUKANSPACE SYSTEM DIAGNOSTIC REPORT          #');
    buffer.writeln('############################################################');
    buffer.writeln('Generated At : $now');
    buffer.writeln('App Version  : 1.0.0+1');
    buffer.writeln('Platform     : ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart Runtime : ${kReleaseMode ? "Release Mode" : (kProfileMode ? "Profile Mode" : "Debug Mode")}');
    buffer.writeln('Locale       : ${Platform.localeName}');
    buffer.writeln('============================================================\n');

    // 1. EXECUTIVE ISSUE SUMMARY
    final errorEntries = _memoryBuffer.where((e) => e.level == 'ERROR').toList();
    final warnEntries = _memoryBuffer.where((e) => e.level == 'WARN').toList();

    buffer.writeln('=== [1] EXECUTIVE ISSUE SUMMARY ===');
    buffer.writeln('• Total Errors Logged   : ${errorEntries.length}');
    buffer.writeln('• Total Warnings Logged : ${warnEntries.length}');

    if (errorEntries.isNotEmpty) {
      buffer.writeln('\n🚨 RECENT CRITICAL ERRORS:');
      for (int i = 0; i < errorEntries.length && i < 5; i++) {
        final err = errorEntries[errorEntries.length - 1 - i];
        buffer.writeln('  #${i + 1} [${err.tag}] ${err.message}');
        if (err.errorDetails != null) {
          final firstLine = err.errorDetails!.split('\n').first;
          buffer.writeln('     Error: $firstLine');
        }
      }
    } else {
      buffer.writeln('✅ No critical errors logged in this session.');
    }
    buffer.writeln('============================================================\n');

    // 2. SQLITE DATABASE DIAGNOSTICS
    buffer.writeln('=== [2] DATABASE HEALTH CHECK ===');
    try {
      final db = await DBProvider.instance.database;
      final dbPath = await getDatabasesPath();
      final fullPath = join(dbPath, 'dukan_space_inventory.db');
      final dbFile = File(fullPath);
      final exists = await dbFile.exists();
      final sizeKb = exists ? (await dbFile.length()) / 1024 : 0;

      buffer.writeln('• DB File Exists : $exists');
      buffer.writeln('• DB File Path   : $fullPath');
      buffer.writeln('• DB File Size   : ${sizeKb.toStringAsFixed(2)} KB');

      // Table Counts
      final modelCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM ${DBProvider.tablePhoneModels}'),
          ) ?? 0;
      final inventoryCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM ${DBProvider.tableInventory}'),
          ) ?? 0;
      final stockSum = Sqflite.firstIntValue(
            await db.rawQuery('SELECT SUM(stock_count) FROM ${DBProvider.tableInventory}'),
          ) ?? 0;
      final distinctGroups = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(DISTINCT accessory_group_id) FROM ${DBProvider.tablePhoneModels}'),
          ) ?? 0;

      buffer.writeln('• Phone Models (Col A) : $modelCount records');
      buffer.writeln('• Distinct Groups (B)  : $distinctGroups unique groups');
      buffer.writeln('• Inventory Items      : $inventoryCount items');
      buffer.writeln('• Total Stock Units    : $stockSum units');

      // Integrity Check
      final integrity = await db.rawQuery('PRAGMA integrity_check(1)');
      buffer.writeln('• SQLite Integrity     : ${integrity.isNotEmpty ? integrity.first.values.first : "OK"}');
    } catch (e) {
      buffer.writeln('⚠️ Database inspection error: $e');
    }
    buffer.writeln('============================================================\n');

    // 3. FULL CHRONOLOGICAL ACTION & BREAK LOGS
    buffer.writeln('=== [3] FULL CHRONOLOGICAL LOGS ===');
    final logText = await getFullLogText();
    buffer.writeln(logText.isEmpty ? 'No events recorded in log file.' : logText);
    buffer.writeln('\n############################################################');
    buffer.writeln('#                     END OF REPORT                        #');
    buffer.writeln('############################################################');

    return buffer.toString();
  }

  Future<void> shareLogs({Map<String, int>? dbStats}) async {
    logAction('SHARE', 'User triggered shareLogs action');
    try {
      final report = await generateDiagnosticReport(dbStats: dbStats);
      final dir = await getTemporaryDirectory();
      final reportFile = File(join(dir.path, 'dukanspace_break_report.txt'));
      await reportFile.writeAsString(report);

      await Share.shareXFiles(
        [XFile(reportFile.path, mimeType: 'text/plain')],
        subject: 'DukanSpace Break Logs & System Diagnostics',
        text: 'DukanSpace Diagnostic & Break Report attached.',
      );
      logInfo('SHARE', 'Native Android share sheet opened successfully');
    } catch (e, stack) {
      logError('SHARE', 'Failed to share report via native intent', e, stack);
      // Fallback: share as raw text
      final report = await generateDiagnosticReport(dbStats: dbStats);
      await Share.share(report, subject: 'DukanSpace Break Report');
    }
  }
}
