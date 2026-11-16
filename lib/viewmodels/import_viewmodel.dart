import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../database/inventory_repository.dart';
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

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
        notifyListeners();
        return;
      }

      _parsedResult = await _parserService.parseExcelBytes(bytes);
      _statusMessage = 'Parsed ${_parsedResult!.phoneModels.length} models successfully.';
    } catch (e) {
      _statusMessage = 'Failed to load file: ${e.toString()}';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> commitImport(ImportMode mode) async {
    if (_parsedResult == null || _parsedResult!.phoneModels.isEmpty) {
      _statusMessage = 'No valid data to import.';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _statusMessage = mode == ImportMode.replace
        ? 'Replacing all existing models...'
        : 'Merging models into database...';
    notifyListeners();

    try {
      if (mode == ImportMode.replace) {
        await _repository.bulkReplacePhoneModels(_parsedResult!.phoneModels);
      } else {
        await _repository.bulkUpsertPhoneModels(_parsedResult!.phoneModels);
      }

      _statusMessage = 'Import completed! ${_parsedResult!.phoneModels.length} records processed.';
      _parsedResult = null;
      _selectedFileName = null;
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Database import error: ${e.toString()}';
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

