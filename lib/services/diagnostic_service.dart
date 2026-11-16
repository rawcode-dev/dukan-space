import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DiagnosticLogEntry {
  final DateTime timestamp;
  final String level; // INFO, WARN, ERROR
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
    final timeStr = timestamp.toIso8601String().substring(0, 19).replaceAll('T', ' ');
    final buffer = StringBuffer('[$timeStr] [$level] [$tag] $message');
    if (errorDetails != null && errorDetails!.isNotEmpty) {
      buffer.write('\n  ↳ Details: $errorDetails');
    }
    return buffer.toString();
  }
}

class DiagnosticService {
  DiagnosticService._internal();
  static final DiagnosticService instance = DiagnosticService._internal();

  static const String _logFileName = 'dukan_diagnostics.log';
  static const int _maxInMemoryEntries = 150;
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
        await _logFile!.writeAsString('--- DukanSpace Diagnostics Initialized ---\n');
      }
      _isInitialized = true;
      logInfo('System', 'Diagnostic logger initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize DiagnosticService file: $e');
    }
  }

  void logInfo(String tag, String message) {
    _record('INFO', tag, message);
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

    // Maintain in-memory circular buffer for fast UI display
    if (_memoryBuffer.length >= _maxInMemoryEntries) {
      _memoryBuffer.removeAt(0);
    }
    _memoryBuffer.add(entry);

    // Print to debug console
    debugPrint(entry.toFormattedString());

    // Asynchronously append to disk file
    _appendToFile(entry);
  }

  Future<void> _appendToFile(DiagnosticLogEntry entry) async {
    if (_logFile == null) return;
    try {
      if (await _logFile!.exists()) {
        final length = await _logFile!.length();
        // If file exceeds max size, trim it to save flash memory on budget devices
        if (length > _maxFileSizeBytes) {
          await _logFile!.writeAsString('--- Log Truncated Due to Size Limit ---\n');
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
    logInfo('System', 'Diagnostics logs cleared by user');
  }

  Future<String> generateDiagnosticReport({Map<String, int>? dbStats}) async {
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln('DUKANSPACE SYSTEM DIAGNOSTIC REPORT');
    buffer.writeln('Generated At: $now');
    buffer.writeln('Platform: Android / Flutter');
    buffer.writeln('App Version: 1.0.0+1');
    buffer.writeln('==============================================\n');

    buffer.writeln('--- DATABASE STATUS ---');
    if (dbStats != null) {
      buffer.writeln('• Phone Models Count : ${dbStats['models'] ?? 0}');
      buffer.writeln('• Inventory Items     : ${dbStats['items'] ?? 0}');
      buffer.writeln('• Total Stock Count   : ${dbStats['stock'] ?? 0}');
    } else {
      buffer.writeln('• Status: Database connected');
    }
    buffer.writeln('');

    buffer.writeln('--- RECENT SYSTEM & BREAK LOGS ---');
    final logText = await getFullLogText();
    buffer.writeln(logText.isEmpty ? 'No errors or log records captured.' : logText);

    return buffer.toString();
  }

  Future<void> shareLogs({Map<String, int>? dbStats}) async {
    try {
      final report = await generateDiagnosticReport(dbStats: dbStats);
      final dir = await getTemporaryDirectory();
      final reportFile = File(join(dir.path, 'dukanspace_break_logs.txt'));
      await reportFile.writeAsString(report);

      await Share.shareXFiles(
        [XFile(reportFile.path, mimeType: 'text/plain')],
        subject: 'DukanSpace Break Logs & System Diagnostics',
        text: 'Attached is the DukanSpace diagnostic report including system error logs and device status.',
      );
    } catch (e) {
      debugPrint('Error sharing diagnostic logs: $e');
      // Fallback to text sharing if file sharing fails
      final report = await generateDiagnosticReport(dbStats: dbStats);
      await Share.share(
        report,
        subject: 'DukanSpace Break Logs & System Diagnostics',
      );
    }
  }
}
