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

      // Prepare query parameters
      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      if (filterTypes != null && filterTypes.isNotEmpty) {
        // Convert enum values to the format expected by the API
        final types = filterTypes.map((type) {
          switch (type) {
            case LabelType.fgPallet:
              return 'fg_pallet';
            case LabelType.roll:
              return 'roll';
            case LabelType.fgLocation:
              return 'fg_location';
            case LabelType.paperRollLocation:
              return 'paper_roll_location';
          }
        }).join(',');

        queryParams['type'] = types;
      }

      onProgress?.call(ExportProgress(0.3, 'Fetching data...'));

      // Print debug information
      print('Preparing to fetch export data with parameters:');
      print('Start Date: $startDate');
      print('End Date: $endDate');
      print('Filter Types: $filterTypes');
      print('Query Parameters: $queryParams');

      final response = await _apiService.get(
        ApiService.exportEndpoint,
        queryParams: queryParams,
      );

      print('Export API Response: $response');

      // Validate response structure
      if (!response.containsKey('data')) {
        throw Exception('Invalid response format: missing data field');
      }

      final exportData = response['data'] as List<dynamic>;
      if (exportData.isEmpty) {
        throw Exception('No data available for export');
      }

      onProgress?.call(ExportProgress(0.5, 'Creating Excel file...'));

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add headers
      final headers = [
        'Scan Time',
        'Label Type',
        'Identifier',
        'Additional Info'
      ];
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = headers[i]
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#E0E0E0',
            horizontalAlign: HorizontalAlign.Center,
          );
      }

      onProgress?.call(ExportProgress(0.6, 'Processing data...'));

      // Add data
      for (var i = 0; i < exportData.length; i++) {
        final row = exportData[i];
        final rowIndex = i + 1;

        // Safely extract values with null checks
        final scanTime = row['scanTime'] ?? row['check_in'] ?? '';
        final labelType = row['labelType'] ?? row['label_type'] ?? '';
        final identifier = row['identifier'] ?? '';
        final additionalInfo =
            row['additionalInfo'] ?? row['additional_info'] ?? '';

        sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          ..value = scanTime;
        sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          ..value = labelType;
        sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          ..value = identifier;
        sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          ..value = additionalInfo;

        if (i % 100 == 0) {
          onProgress?.call(ExportProgress(
            0.6 + (i / exportData.length) * 0.3,
            'Processing data... (${((i / exportData.length) * 100).toInt()}%)',
          ));
        }
      }

      onProgress?.call(ExportProgress(0.9, 'Saving file...'));

      // Generate file name with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'label_export_$timestamp.xlsx';

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      print('Excel file saved successfully at: $filePath');

      onProgress?.call(ExportProgress(1.0, 'Export completed'));

      return filePath;
    } catch (e, stackTrace) {
      print('Export error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to export data: $e');
    }
  }
}
