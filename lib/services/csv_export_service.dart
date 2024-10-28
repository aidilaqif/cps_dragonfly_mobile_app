import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/fg_location_label.dart';
import '../models/fg_pallet_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/roll_label.dart';
import '../models/scan_session.dart';
import '../models/label_types.dart';

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
    excel.delete('Sheet1');

    // Create All Scans sheet
    final allScansSheet = excel['All Scans'];
    _createAllScansSheet(allScansSheet, sessions, filterTypes);

    // Create type-specific sheets
    for (var type in LabelType.values) {
      if (filterTypes == null || filterTypes.contains(type)) {
        final sheet = excel[_getLabelTypeName(type)];
        _createTypeSpecificSheet(sheet, type, sessions);
      }
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _generateFileName(sessions, sessionIndex);
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  void _createAllScansSheet(Sheet sheet, List<ScanSession> sessions, List<LabelType>? filterTypes) {
    // Create headers
    _createHeaderRow(sheet, [
      'Session',
      'Scan Time',
      'Label Type',
      'ID',
      'Additional Info',
      'Is Rescan',
      'Session ID',
    ]);

    int row = 1;
    for (int sessionIdx = 0; sessionIdx < sessions.length; sessionIdx++) {
      final session = sessions[sessionIdx];
      final scans = session.scans.where((scan) {
        final type = _getLabelType(scan);
        return filterTypes?.contains(type) ?? true;
      }).toList();

      for (var scan in scans) {
        _addScanRow(sheet, row++, scan, sessionIdx + 1, session.sessionId);
      }
    }
  }

  void _createTypeSpecificSheet(Sheet sheet, LabelType type, List<ScanSession> sessions) {
    final headers = _getTypeSpecificHeaders(type);
    _createHeaderRow(sheet, headers);

    int row = 1;
    for (var session in sessions) {
      for (var scan in session.scans) {
        if (_getLabelType(scan) == type) {
          _addTypeSpecificRow(sheet, row++, scan, type, session.sessionId);
        }
      }
    }
  }

  void _createHeaderRow(Sheet sheet, List<String> headers) {
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i]
        ..cellStyle = CellStyle(bold: true);
    }
  }

  void _addScanRow(Sheet sheet, int row, dynamic scan, int sessionNumber, String sessionId) {
    final type = _getLabelType(scan);
    final data = [
      'Session $sessionNumber',
      _formatDateTime(scan.timeLog),
      _getLabelTypeName(type),
      _getScanId(scan),
      _getAdditionalInfo(scan),
      scan.isRescan.toString(),
      sessionId,
    ];

    _addDataRow(sheet, row, data);
  }

  void _addTypeSpecificRow(Sheet sheet, int row, dynamic scan, LabelType type, String sessionId) {
    List<dynamic> data;

    switch (type) {
      case LabelType.fgPallet:
        final palletLabel = scan as FGPalletLabel;
        data = [
          _formatDateTime(palletLabel.timeLog),
          palletLabel.plateId,
          palletLabel.workOrder,
          palletLabel.isRescan.toString(),
          sessionId,
        ];
        break;

      case LabelType.roll:
        final rollLabel = scan as RollLabel;
        data = [
          _formatDateTime(rollLabel.timeLog),
          rollLabel.rollId,
          rollLabel.isRescan.toString(),
          sessionId,
        ];
        break;

      case LabelType.fgLocation:
      case LabelType.paperRollLocation:
        final locationLabel = scan as dynamic;
        data = [
          _formatDateTime(locationLabel.timeLog),
          locationLabel.locationId,
          locationLabel.isRescan.toString(),
          sessionId,
        ];
        break;
    }

    _addDataRow(sheet, row, data);
  }

  List<String> _getTypeSpecificHeaders(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return ['Scan Time', 'Plate ID', 'Work Order', 'Is Rescan', 'Session ID'];
      case LabelType.roll:
        return ['Scan Time', 'Roll ID', 'Is Rescan', 'Session ID'];
      case LabelType.fgLocation:
      case LabelType.paperRollLocation:
        return ['Scan Time', 'Location ID', 'Is Rescan', 'Session ID'];
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

  String _getAdditionalInfo(dynamic scan) {
    if (scan is FGPalletLabel) return 'Work Order: ${scan.workOrder}';
    return '';
  }
}