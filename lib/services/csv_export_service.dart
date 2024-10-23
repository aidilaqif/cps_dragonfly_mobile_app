import 'dart:io';
import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:intl/intl.dart';

class CsvExportService {
  static final CsvExportService _instance = CsvExportService._internal();
  factory CsvExportService() => _instance;
  CsvExportService._internal();

  String _generateFileName(List<ScanSession> sessions, int? sessionIndex) {
    final dateFormat = DateFormat('yyyy_MM_dd_HHmm');
    final now = DateTime.now();
    
    if (sessionIndex != null) {
      final session = sessions[sessionIndex];
      return 'Scan_Session_${sessionIndex + 1}_${dateFormat.format(session.startTime)}.xlsx';
    } else if (sessions.length == 1) {
      return 'Current_Session_Scans_${dateFormat.format(now)}.xlsx';
    } else {
      final startDate = sessions.first.startTime;
      final endDate = sessions.last.startTime;
      return 'All_Sessions_${dateFormat.format(startDate)}_to_${dateFormat.format(endDate)}.xlsx';
    }
  }

  Future<String> exportToExcel({
    required List<ScanSession> sessions,
    List<LabelType>? filterTypes,
    int? sessionIndex,
  }) async {
    final excel = Excel.createExcel();
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // Create All Scans sheet
    final allScansSheet = excel['All Scans'];
    _createHeaderRow(allScansSheet, [
      'Session',
      'Scan Time',
      'Label Type',
      'ID',
      'Work Order',
      'Additional Info',
      'Is Rescan'
    ]);

    // Create type-specific sheets
    final typeSheets = {
      for (var type in LabelType.values)
        type: excel[_getLabelTypeName(type)]
    };

    // Create headers for type-specific sheets
    for (var type in LabelType.values) {
      _createTypeSpecificHeader(typeSheets[type]!, type);
    }

    // Create session-specific sheets if needed
    Map<int, Sheet> sessionSheets = {};
    if (sessionIndex == null) {
      for (int i = 0; i < sessions.length; i++) {
        final sheet = excel['Session ${i + 1}'];
        sessionSheets[i] = sheet;
        _createHeaderRow(sheet, [
          'Scan Time',
          'Label Type',
          'ID',
          'Work Order',
          'Additional Info',
          'Is Rescan'
        ]);
      }
    }

    // Process data
    int allScansRow = 1;
    for (int sessionIdx = 0; sessionIdx < sessions.length; sessionIdx++) {
      if (sessionIndex != null && sessionIdx != sessionIndex) continue;
      
      final session = sessions[sessionIdx];
      final scans = session.scans.where((scan) {
        final type = _getLabelType(scan);
        return filterTypes?.contains(type) ?? true;
      }).toList();

      for (var scan in scans) {
        final type = _getLabelType(scan);
        final isRescan = _checkIfRescan(scan, scans);
        
        // Add to All Scans sheet
        _addDataRow(allScansSheet, allScansRow++, [
          'Session ${sessionIdx + 1}',
          _formatDateTime(scan.timeLog),
          _getLabelTypeName(type),
          _getScanId(scan),
          _getWorkOrder(scan),
          _getAdditionalInfo(scan),
          isRescan.toString()
        ]);

        // Add to type-specific sheet
        final typeSheet = typeSheets[type]!;
        _addTypeSpecificData(typeSheet, scan, sessionIdx + 1);

        // Add to session sheet if applicable
        if (sessionSheets.containsKey(sessionIdx)) {
          final sessionSheet = sessionSheets[sessionIdx]!;
          _addDataRow(sessionSheet, sessionSheets[sessionIdx]!.maxRows, [
            _formatDateTime(scan.timeLog),
            _getLabelTypeName(type),
            _getScanId(scan),
            _getWorkOrder(scan),
            _getAdditionalInfo(scan),
            isRescan.toString()
          ]);
        }
      }
    }

    // Add formulas for data linking
    _linkSheets(excel, allScansSheet, typeSheets.values.toList(), sessionSheets.values.toList());

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _generateFileName(sessions, sessionIndex);
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  void _createHeaderRow(Sheet sheet, List<String> headers) {
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i]
        ..cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
    }
  }

  void _createTypeSpecificHeader(Sheet sheet, LabelType type) {
    final headers = _getTypeSpecificHeaders(type);
    _createHeaderRow(sheet, headers);
  }

  List<String> _getTypeSpecificHeaders(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return ['Session', 'Scan Time', 'Plate ID', 'Work Order', 'Is Rescan'];
      case LabelType.roll:
        return ['Session', 'Scan Time', 'Roll ID', 'Is Rescan'];
      case LabelType.fgLocation:
      case LabelType.paperRollLocation:
        return ['Session', 'Scan Time', 'Location ID', 'Is Rescan'];
      default:
        return [];
    }
  }

  void _addDataRow(Sheet sheet, int rowIndex, List<dynamic> data) {
    for (var i = 0; i < data.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
        ..value = data[i];
    }
  }

  void _addTypeSpecificData(Sheet sheet, dynamic scan, int sessionNumber) {
    final rowIndex = sheet.maxRows;
    final type = _getLabelType(scan);
    
    switch (type) {
      case LabelType.fgPallet:
        _addDataRow(sheet, rowIndex, [
          sessionNumber,
          _formatDateTime(scan.timeLog),
          scan.plateId,
          scan.workOrder,
          _checkIfRescan(scan, []).toString(),
        ]);
        break;
      case LabelType.roll:
        _addDataRow(sheet, rowIndex, [
          sessionNumber,
          _formatDateTime(scan.timeLog),
          scan.rollId,
          _checkIfRescan(scan, []).toString(),
        ]);
        break;
      case LabelType.fgLocation:
      case LabelType.paperRollLocation:
        _addDataRow(sheet, rowIndex, [
          sessionNumber,
          _formatDateTime(scan.timeLog),
          scan.locationId,
          _checkIfRescan(scan, []).toString(),
        ]);
        break;
    }
  }

  void _linkSheets(Excel excel, Sheet mainSheet, List<Sheet> typeSheets, List<Sheet> sessionSheets) {
    // Add references to link data between sheets
    for (var typeSheet in typeSheets) {
      for (var row = 1; row < typeSheet.maxRows; row++) {
        final mainSheetRow = _findCorrespondingRow(mainSheet, typeSheet, row);
        if (mainSheetRow != -1) {
          // Link relevant cells using Excel formulas
          typeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .setFormula('=\'All Scans\'!B$mainSheetRow');
        }
      }
    }
  }

  int _findCorrespondingRow(Sheet mainSheet, Sheet typeSheet, int typeSheetRow) {
    // Implementation to find matching row in main sheet
    // Based on unique identifiers like scan time and ID
    return -1; // Placeholder
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  LabelType _getLabelType(dynamic scan) {
    if (scan is FGPalletLabel) return LabelType.fgPallet;
    if (scan is RollLabel) return LabelType.roll;
    if (scan is FGLocationLabel) return LabelType.fgLocation;
    if (scan is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw Exception('Unknown scan type');
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet Label';
      case LabelType.roll:
        return 'Roll Label';
      case LabelType.fgLocation:
        return 'FG Location Label';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location Label';
    }
  }

  String _getScanId(dynamic scan) {
    if (scan is FGPalletLabel) return scan.plateId;
    if (scan is RollLabel) return scan.rollId;
    if (scan is FGLocationLabel) return scan.locationId;
    if (scan is PaperRollLocationLabel) return scan.locationId;
    return '';
  }

  String _getWorkOrder(dynamic scan) {
    if (scan is FGPalletLabel) return scan.workOrder;
    return '';
  }

  String _getAdditionalInfo(dynamic scan) {
    // Add any additional information based on scan type
    return '';
  }

  bool _checkIfRescan(dynamic scan, List<dynamic> allScans) {
    final id = _getScanId(scan);
    return allScans.where((s) => _getScanId(s) == id && s.timeLog.isBefore(scan.timeLog)).isNotEmpty;
  }
}