import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database/inventory_repository.dart';
import '../services/diagnostic_service.dart';
import '../services/excel_parser_service.dart';

enum ImportMode { merge, replace }

class ImportViewModel extends ChangeNotifier {
  final InventoryRepository _repository;
  final ExcelParserService _parserService;

  ImportViewModel({
    required InventoryRepository repository,
    required ExcelParserService parserService,
  })  : _repository = repository,
        _parserService = parserService;

  bool _isProcessing = false;
  String? _statusMessage;
  ExcelParseResult? _parsedResult;
  String? _selectedFileName;

  bool get isProcessing => _isProcessing;
  String? get statusMessage => _statusMessage;
  ExcelParseResult? get parsedResult => _parsedResult;
  String? get selectedFileName => _selectedFileName;

  Future<void> pickAndParseExcel() async {
    _statusMessage = null;
    DiagnosticService.instance.logAction('IMPORT_VM', 'pickAndParseExcel initiated');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        DiagnosticService.instance.logInfo('IMPORT_VM', 'File selection cancelled by user');
        return;
      }

      final file = result.files.first;
      _selectedFileName = file.name;
      _isProcessing = true;
      _statusMessage = 'Parsing Excel sheet in background isolate...';
      notifyListeners();

      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        _statusMessage = 'Error: Selected file is empty.';
        _isProcessing = false;
        DiagnosticService.instance.logWarning('IMPORT_VM', 'Selected file "${file.name}" had 0 bytes');
        notifyListeners();
        return;
      }

      DiagnosticService.instance.logInfo(
        'IMPORT_VM',
        'File "${file.name}" loaded (${(bytes.length / 1024).toStringAsFixed(1)} KB). Starting Isolate parser...',
      );

      _parsedResult = await _parserService.parseExcelBytes(bytes);

      if (_parsedResult!.errorMessage != null) {
        _statusMessage = _parsedResult!.errorMessage;
        DiagnosticService.instance.logError('IMPORT_VM', 'Parsing returned error: ${_parsedResult!.errorMessage}');
      } else {
        _statusMessage = 'Parsed ${_parsedResult!.phoneModels.length} models successfully.';
        DiagnosticService.instance.logInfo(
          'IMPORT_VM',
          'Parsed ${_parsedResult!.phoneModels.length} models (${_parsedResult!.totalRowsParsed} total rows, ${_parsedResult!.skippedRows} skipped)',
        );
      }
    } catch (e, stack) {
      _statusMessage = 'Failed to load file: ${e.toString()}';
      DiagnosticService.instance.logError('IMPORT_VM', 'pickAndParseExcel failed', e, stack);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> commitImport(ImportMode mode) async {
    if (_parsedResult == null || _parsedResult!.phoneModels.isEmpty) {
      _statusMessage = 'No valid data to import.';
      DiagnosticService.instance.logWarning('IMPORT_VM', 'commitImport aborted: 0 models in parsed result');
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _statusMessage = mode == ImportMode.replace
        ? 'Replacing all existing models...'
        : 'Merging models into database...';
    notifyListeners();

    DiagnosticService.instance.logAction('IMPORT_VM', 'commitImport strategy confirmed', {
      'strategy': mode == ImportMode.replace ? 'REPLACE_ALL' : 'MERGE_UPSERT',
      'count': _parsedResult!.phoneModels.length,
    });

    final stopwatch = Stopwatch()..start();
    try {
      if (mode == ImportMode.replace) {
        await _repository.bulkReplacePhoneModels(_parsedResult!.phoneModels);
      } else {
        await _repository.bulkUpsertPhoneModels(_parsedResult!.phoneModels);
      }

      stopwatch.stop();
      _statusMessage = 'Import completed! ${_parsedResult!.phoneModels.length} records processed in ${stopwatch.elapsedMilliseconds}ms.';
      DiagnosticService.instance.logInfo('IMPORT_VM', 'commitImport completed in ${stopwatch.elapsedMilliseconds}ms');

      _parsedResult = null;
      _selectedFileName = null;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      _statusMessage = 'Database import error: ${e.toString()}';
      DiagnosticService.instance.logError('IMPORT_VM', 'commitImport failed', e, stack);
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _parsedResult = null;
    _selectedFileName = null;
    _statusMessage = null;
    _isProcessing = false;
    notifyListeners();
  }
}
