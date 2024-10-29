import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/fg_location_label.dart';
import '../models/fg_pallet_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/roll_label.dart';
import '../models/label_types.dart';

class CsvExportService {
  static final CsvExportService _instance = CsvExportService._internal();
  factory CsvExportService() => _instance;
  CsvExportService._internal();

  String _generateFileName() {
    final dateFormat = DateFormat('yyyy_MM_dd_HHmm');
    final now = DateTime.now();
    return 'Scan_Data_Export_${dateFormat.format(now)}.xlsx';
  }

  Future<String> exportToExcel({
    required List<dynamic> data,
    List<LabelType>? filterTypes,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Create type-specific sheets
    for (var type in LabelType.values) {
      if (filterTypes == null || filterTypes.contains(type)) {
        final typeData = data.where((scan) => _getScanType(scan) == type).toList();
        if (typeData.isNotEmpty) {
          final sheet = excel[_getLabelTypeName(type)];
          _createTypeSpecificSheet(sheet, typeData);
        }
      }
    }

    // Create All Scans sheet
    final allScansSheet = excel['All Scans'];
    _createAllScansSheet(allScansSheet, data);

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _generateFileName();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  void _createAllScansSheet(Sheet sheet, List<dynamic> data) {
    // Create headers
    _createHeaderRow(sheet, [
      'Scan Time',
      'Label Type',
      'ID',
      'Additional Info',
    ]);

    int row = 1;
    for (var scan in data) {
      _addScanRow(sheet, row++, scan);
    }
  }

  void _createTypeSpecificSheet(Sheet sheet, List<dynamic> data) {
    if (data.isEmpty) return;

    final headers = _getTypeSpecificHeaders(data.first);
    _createHeaderRow(sheet, headers);

    int row = 1;
    for (var scan in data) {
      _addTypeSpecificRow(sheet, row++, scan);
    }
  }

  void _createHeaderRow(Sheet sheet, List<String> headers) {
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i]
        ..cellStyle = CellStyle(bold: true);
    }
  }

  void _addScanRow(Sheet sheet, int row, dynamic scan) {
    final type = _getScanType(scan);
    final data = [
      _formatDateTime(scan.checkIn),
      _getLabelTypeName(type),
      _getScanId(scan),
      _getAdditionalInfo(scan),
    ];

    _addDataRow(sheet, row, data);
  }

  void _addTypeSpecificRow(Sheet sheet, int row, dynamic scan) {
    List<dynamic> data;

    if (scan is FGPalletLabel) {
      data = [
        _formatDateTime(scan.checkIn),
        scan.plateId,
        scan.workOrder,
        scan.rawValue,
      ];
    } else if (scan is RollLabel) {
      data = [
        _formatDateTime(scan.checkIn),
        scan.rollId,
        scan.batchNumber,
        scan.sequenceNumber,
      ];
    } else {
      // Location labels (both types)
      final locationLabel = scan as dynamic;
      data = [
        _formatDateTime(scan.checkIn),
        locationLabel.locationId,
        scan is FGLocationLabel ? locationLabel.areaType : locationLabel.rowNumber,
      ];
    }

    _addDataRow(sheet, row, data);
  }

  List<String> _getTypeSpecificHeaders(dynamic scan) {
    if (scan is FGPalletLabel) {
      return ['Scan Time', 'Plate ID', 'Work Order', 'Raw Value'];
    } else if (scan is RollLabel) {
      return ['Scan Time', 'Roll ID', 'Batch Number', 'Sequence Number'];
    } else if (scan is FGLocationLabel) {
      return ['Scan Time', 'Location ID', 'Area Type'];
    } else {
      return ['Scan Time', 'Location ID', 'Row Number'];
    }
  }

  void _addDataRow(Sheet sheet, int row, List<dynamic> data) {
    for (var i = 0; i < data.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = data[i];
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  LabelType _getScanType(dynamic scan) {
    if (scan is FGPalletLabel) return LabelType.fgPallet;
    if (scan is RollLabel) return LabelType.roll;
    if (scan is FGLocationLabel) return LabelType.fgLocation;
    if (scan is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw Exception('Unknown scan type');
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet Labels';
      case LabelType.roll:
        return 'Roll Labels';
      case LabelType.fgLocation:
        return 'FG Location Labels';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location Labels';
    }
  }

  String _getScanId(dynamic scan) {
    if (scan is FGPalletLabel) return scan.plateId;
    if (scan is RollLabel) return scan.rollId;
    if (scan is FGLocationLabel) return scan.locationId;
    if (scan is PaperRollLocationLabel) return scan.locationId;
    return '';
  }

  String _getAdditionalInfo(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'Work Order: ${scan.workOrder}, Raw Value: ${scan.rawValue}';
    } else if (scan is RollLabel) {
      return 'Batch: ${scan.batchNumber}, Sequence: ${scan.sequenceNumber}';
    } else if (scan is FGLocationLabel) {
      return 'Area Type: ${scan.areaType}';
    } else if (scan is PaperRollLocationLabel) {
      return 'Row: ${scan.rowNumber}, Position: ${scan.positionNumber}';
    }
    return '';
  }
}