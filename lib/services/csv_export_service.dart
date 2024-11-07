import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/label_types.dart';
import '../services/api_service.dart';

class ExportProgress {
  final double progress;
  final String message;

  ExportProgress(this.progress, this.message);
}

class CsvExportService {
  static final CsvExportService _instance = CsvExportService._internal();
  final ApiService _apiService = ApiService();
  
  factory CsvExportService() => _instance;
  
  CsvExportService._internal();

  Future<String> exportToExcel({
    required DateTime? startDate,
    required DateTime? endDate,
    List<LabelType>? filterTypes,
    ValueChanged<ExportProgress>? onProgress,
  }) async {
    try {
      onProgress?.call(ExportProgress(0.1, 'Initializing export...'));

      // Fetch data from API
      final data = await _fetchData(
        startDate: startDate,
        endDate: endDate,
        filterTypes: filterTypes,
        onProgress: onProgress,
      );

      onProgress?.call(ExportProgress(0.4, 'Creating Excel workbook...'));

      // Create and populate Excel workbook
      final excel = await _createWorkbook(
        data,
        filterTypes: filterTypes,
        onProgress: onProgress,
      );

      onProgress?.call(ExportProgress(0.8, 'Saving file...'));

      // Save and return file path
      final filePath = await _saveExcelFile(excel);

      onProgress?.call(ExportProgress(1.0, 'Export completed'));

      return filePath;
    } catch (e) {
      print('Error in exportToExcel: $e');
      throw Exception('Failed to export data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchData({
    DateTime? startDate,
    DateTime? endDate,
    List<LabelType>? filterTypes,
    ValueChanged<ExportProgress>? onProgress,
  }) async {
    try {
      onProgress?.call(ExportProgress(0.2, 'Fetching data from server...'));

      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (filterTypes != null && filterTypes.isNotEmpty) {
        queryParams['labelTypes'] = filterTypes
            .map((type) => type.toString().split('.').last)
            .join(',');
      }

      final response = await _apiService.get(
        ApiService.exportEndpoint,
        queryParams: queryParams,
      );

      return List<Map<String, dynamic>>.from(response['data']);
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Failed to fetch export data: $e');
    }
  }

  Future<Excel> _createWorkbook(
    List<Map<String, dynamic>> data, {
    List<LabelType>? filterTypes,
    ValueChanged<ExportProgress>? onProgress,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Create sheets based on filter types
    final sheets = await _createSheets(excel, filterTypes);
    
    onProgress?.call(ExportProgress(0.5, 'Processing data...'));

    // Add data to sheets
    await _populateSheets(
      sheets,
      data,
      filterTypes: filterTypes,
      onProgress: onProgress,
    );

    onProgress?.call(ExportProgress(0.7, 'Formatting worksheets...'));

    // Apply formatting
    _applyFormatting(sheets);

    return excel;
  }

  Map<String, Sheet> _createSheets(Excel excel, List<LabelType>? filterTypes) {
    final sheets = <String, Sheet>{
      'All Labels': excel['All Labels'],
    };

    // Create type-specific sheets based on filters
    if (filterTypes == null || filterTypes.contains(LabelType.fgPallet)) {
      sheets['FG Pallets'] = excel['FG Pallets'];
    }
    if (filterTypes == null || filterTypes.contains(LabelType.roll)) {
      sheets['Rolls'] = excel['Rolls'];
    }
    if (filterTypes == null || filterTypes.contains(LabelType.fgLocation)) {
      sheets['FG Locations'] = excel['FG Locations'];
    }
    if (filterTypes == null || filterTypes.contains(LabelType.paperRollLocation)) {
      sheets['Paper Roll Locations'] = excel['Paper Roll Locations'];
    }

    // Add headers to sheets
    _addHeaders(sheets);

    return sheets;
  }

  void _addHeaders(Map<String, Sheet> sheets) {
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#E0E0E0',
      horizontalAlign: HorizontalAlign.Center,
    );

    // All Labels sheet headers
    _addHeaderRow(
      sheets['All Labels']!,
      ['Scan Time', 'Label Type', 'Identifier', 'Additional Info'],
      headerStyle,
    );

    // Type-specific sheet headers
    if (sheets.containsKey('FG Pallets')) {
      _addHeaderRow(
        sheets['FG Pallets']!,
        ['Scan Time', 'Plate ID', 'Work Order', 'Raw Value'],
        headerStyle,
      );
    }
    if (sheets.containsKey('Rolls')) {
      _addHeaderRow(
        sheets['Rolls']!,
        ['Scan Time', 'Roll ID', 'Batch Number', 'Sequence Number'],
        headerStyle,
      );
    }
    if (sheets.containsKey('FG Locations')) {
      _addHeaderRow(
        sheets['FG Locations']!,
        ['Scan Time', 'Location ID', 'Area Type'],
        headerStyle,
      );
    }
    if (sheets.containsKey('Paper Roll Locations')) {
      _addHeaderRow(
        sheets['Paper Roll Locations']!,
        ['Scan Time', 'Location ID', 'Row', 'Position'],
        headerStyle,
      );
    }
  }

  void _addHeaderRow(Sheet sheet, List<String> headers, CellStyle headerStyle) {
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i]
        ..cellStyle = headerStyle;
    }
  }

  Future<void> _populateSheets(
    Map<String, Sheet> sheets,
    List<Map<String, dynamic>> data, {
    List<LabelType>? filterTypes,
    ValueChanged<ExportProgress>? onProgress,
  }) async {
    final total = data.length;
    var current = 0;

    for (var item in data) {
      // Add to All Labels sheet
      _addRowToAllLabelsSheet(sheets['All Labels']!, current + 1, item);

      // Add to type-specific sheet
      final labelType = _getLabelType(item['labelType']);
      if (labelType != null && (filterTypes == null || filterTypes.contains(labelType))) {
        final sheet = _getSheetForLabelType(sheets, labelType);
        if (sheet != null) {
          _addRowToTypeSheet(sheet, current + 1, item, labelType);
        }
      }

      current++;
      if (current % 100 == 0) {
        onProgress?.call(ExportProgress(
          0.5 + (current / total) * 0.2,
          'Processing data... (${(current / total * 100).toInt()}%)',
        ));
      }
    }
  }

  void _addRowToAllLabelsSheet(Sheet sheet, int row, Map<String, dynamic> data) {
    final cells = [
      _formatDateTime(data['scanTime']),
      _formatLabelType(data['labelType']),
      data['identifier'] ?? '',
      data['additionalInfo'] ?? '',
    ];

    _addDataRow(sheet, row, cells);
  }

  void _addRowToTypeSheet(Sheet sheet, int row, Map<String, dynamic> data, LabelType type) {
    List<dynamic> cells;
    switch (type) {
      case LabelType.fgPallet:
        cells = [
          _formatDateTime(data['scanTime']),
          data['plateId'],
          data['workOrder'],
          data['rawValue'],
        ];
        break;
      case LabelType.roll:
        cells = [
          _formatDateTime(data['scanTime']),
          data['rollId'],
          data['batchNumber'],
          data['sequenceNumber'],
        ];
        break;
      case LabelType.fgLocation:
        cells = [
          _formatDateTime(data['scanTime']),
          data['locationId'],
          data['areaType'],
        ];
        break;
      case LabelType.paperRollLocation:
        cells = [
          _formatDateTime(data['scanTime']),
          data['locationId'],
          data['row'],
          data['position'],
        ];
        break;
    }
    _addDataRow(sheet, row, cells);
  }

  void _addDataRow(Sheet sheet, int row, List<dynamic> cells) {
    for (var i = 0; i < cells.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = cells[i];
    }
  }

  void _applyFormatting(Map<String, Sheet> sheets) {
    sheets.forEach((name, sheet) {
      _autoSizeColumns(sheet);
      _applyAlternateRowColoring(sheet);
      _addTotalsRow(sheet);
    });
  }

  void _autoSizeColumns(Sheet sheet) {
    final maxWidth = 50.0;
    for (var col = 0; col < sheet.maxCols; col++) {
      double width = 10.0;
      for (var row = 0; row < sheet.maxRows; row++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: row,
        ));
        final value = cell.value.toString();
        width = math.max(width, value.length * 1.2);
      }
      sheet.setColWidth(col, math.min(width, maxWidth));
    }
  }

  void _applyAlternateRowColoring(Sheet sheet) {
    final alternateStyle = CellStyle(
      backgroundColorHex: '#F5F5F5',
    );

    for (var row = 1; row < sheet.maxRows; row++) {
      if (row % 2 == 0) {
        for (var col = 0; col < sheet.maxCols; col++) {
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: row,
          )).cellStyle = alternateStyle;
        }
      }
    }
  }

  void _addTotalsRow(Sheet sheet) {
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#E0E0E0',
    );

    final row = sheet.maxRows;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = 'Total Records:'
      ..cellStyle = totalStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = row - 1 // Subtract header row
      ..cellStyle = totalStyle;
  }

  Future<String> _saveExcelFile(Excel excel) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _generateFileName();
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    return filePath;
  }

  String _formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  String _formatLabelType(String type) {
    return type.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _generateFileName() {
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    return 'Scan_Data_Export_${dateFormat.format(DateTime.now())}.xlsx';
  }

  LabelType? _getLabelType(String type) {
    switch (type) {
      case 'fg_pallet':
        return LabelType.fgPallet;
      case 'roll':
        return LabelType.roll;
      case 'fg_location':
        return LabelType.fgLocation;
      case 'paper_roll_location':
        return LabelType.paperRollLocation;
      default:
        return null;
    }
  }

  Sheet? _getSheetForLabelType(Map<String, Sheet> sheets, LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return sheets['FG Pallets'];
      case LabelType.roll:
        return sheets['Rolls'];
      case LabelType.fgLocation:
        return sheets['FG Locations'];
      case LabelType.paperRollLocation:
        return sheets['Paper Roll Locations'];
    }
  }
}