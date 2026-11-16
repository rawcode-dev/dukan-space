import 'dart:isolate';
import 'package:excel/excel.dart';
import '../models/phone_model.dart';
import 'diagnostic_service.dart';

class ExcelParseResult {
  final List<PhoneModel> phoneModels;
  final int totalRowsParsed;
  final int skippedRows;
  final String? errorMessage;

  const ExcelParseResult({
    required this.phoneModels,
    required this.totalRowsParsed,
    required this.skippedRows,
    this.errorMessage,
  });
}

class ExcelParserService {
  /// Offloads heavy Excel workbook decompression & parsing to an isolated background thread.
  /// This prevents budget devices (with 2GB-3GB RAM) from dropping UI frames or triggering ANRs.
  Future<ExcelParseResult> parseExcelBytes(List<int> bytes) async {
    try {
      final result = await Isolate.run(() => _parseExcelInBackground(bytes));
      DiagnosticService.instance.logInfo(
        'ExcelParser',
        'Parsed ${result.phoneModels.length} models (${result.totalRowsParsed} rows, ${result.skippedRows} skipped)',
      );
      return result;
    } catch (e, stack) {
      DiagnosticService.instance.logError('ExcelParser', 'Parsing failed: ${e.toString()}', e, stack);
      return ExcelParseResult(
        phoneModels: [],
        totalRowsParsed: 0,
        skippedRows: 0,
        errorMessage: 'Parsing failed: ${e.toString()}',
      );
    }
  }

  static ExcelParseResult _parseExcelInBackground(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<PhoneModel> models = [];
    int totalRows = 0;
    int skippedRows = 0;

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;

      for (int i = 0; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty) continue;
        totalRows++;

        final colACell = row.isNotEmpty ? row[0] : null;
        final colBCell = row.length > 1 ? row[1] : null;

        final rawPhoneName = _extractCellValue(colACell);
        final rawGroupId = _extractCellValue(colBCell);

        // Skip headers or incomplete rows
        if (rawPhoneName.isEmpty || rawGroupId.isEmpty) {
          skippedRows++;
          continue;
        }

        // Header detection
        final lowerA = rawPhoneName.toLowerCase();
        final lowerB = rawGroupId.toLowerCase();
        if ((lowerA.contains('phone') || lowerA.contains('model')) &&
            (lowerB.contains('group') || lowerB.contains('id') || lowerB.contains('acc'))) {
          skippedRows++;
          continue;
        }

        models.add(PhoneModel(
          phoneName: rawPhoneName,
          accessoryGroupId: rawGroupId,
        ));
      }
    }

    return ExcelParseResult(
      phoneModels: models,
      totalRowsParsed: totalRows,
      skippedRows: skippedRows,
    );
  }

  static String _extractCellValue(dynamic cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    try {
      final dynamic inner = (val as dynamic).value;
      if (inner != null) return inner.toString().trim();
    } catch (_) {}
    return val.toString().trim();
  }
}

