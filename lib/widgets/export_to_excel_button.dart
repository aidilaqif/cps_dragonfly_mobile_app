import 'dart:io';

import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/label_types.dart';
import '../services/fg_pallet_label_service.dart';
import '../services/roll_label_service.dart';
import '../services/fg_location_label_service.dart';
import '../services/paper_roll_location_label_service.dart';
import '../services/database_service.dart';

class ExportToExcelButton extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<LabelType>? filterTypes;
  final bool showIcon;

  const ExportToExcelButton({
    super.key,
    this.startDate,
    this.endDate,
    this.filterTypes,
    this.showIcon = true,
  });

  @override
  State<ExportToExcelButton> createState() => _ExportToExcelButtonState();
}

class _ExportToExcelButtonState extends State<ExportToExcelButton> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    if (_isExporting) return;

    try {
      setState(() => _isExporting = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preparing export...')),
        );
      }

      final connection = await DatabaseService().connection;
      final excel = Excel.createExcel();
      
      // Create services
      final fgPalletService = FGPalletLabelService(connection);
      final rollService = RollLabelService(connection);
      final fgLocationService = FGLocationLabelService(connection);
      final paperRollLocationService = PaperRollLocationLabelService(connection);

      // Get data
      final data = await Future.wait([
        if (widget.filterTypes?.contains(LabelType.fgPallet) ?? true)
          fgPalletService.list(
            startDate: widget.startDate,
            endDate: widget.endDate,
          ),
        if (widget.filterTypes?.contains(LabelType.roll) ?? true)
          rollService.list(
            startDate: widget.startDate,
            endDate: widget.endDate,
          ),
        if (widget.filterTypes?.contains(LabelType.fgLocation) ?? true)
          fgLocationService.list(
            startDate: widget.startDate,
            endDate: widget.endDate,
          ),
        if (widget.filterTypes?.contains(LabelType.paperRollLocation) ?? true)
          paperRollLocationService.list(
            startDate: widget.startDate,
            endDate: widget.endDate,
          ),
      ]);

      // Create sheets and add data
      for (var labelData in data) {
        if (labelData.isNotEmpty) {
          final sheetName = _getLabelTypeName(labelData.first);
          final sheet = excel[sheetName];
          _addDataToSheet(sheet, labelData);
        }
      }

      // Save and share file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'scan_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = await File('${directory.path}/$fileName').writeAsBytes(excel.encode()!);
      
      await Share.shareXFiles([XFile(file.path)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _addDataToSheet(Sheet sheet, List<dynamic> data) {
    // Add headers
    final headers = _getHeaders(data.first);
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i]
        ..cellStyle = CellStyle(bold: true);
    }

    // Add data
    for (var i = 0; i < data.length; i++) {
      final rowData = _getRowData(data[i]);
      for (var j = 0; j < rowData.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
          ..value = rowData[j];
      }
    }
  }

  List<String> _getHeaders(dynamic item) {
    final baseHeaders = ['Scan Time'];
    if (item is FGPalletLabel) {
      return [...baseHeaders, 'Plate ID', 'Work Order', 'Raw Value'];
    } else if (item is RollLabel) {
      return [...baseHeaders, 'Roll ID'];
    } else {
      return [...baseHeaders, 'Location ID'];
    }
  }

  List<dynamic> _getRowData(dynamic item) {
    final checkIn = DateFormat('yyyy-MM-dd HH:mm:ss').format(item.checkIn);
    if (item is FGPalletLabel) {
      return [checkIn, item.plateId, item.workOrder, item.rawValue];
    } else if (item is RollLabel) {
      return [checkIn, item.rollId];
    } else {
      return [checkIn, item.locationId];
    }
  }

  String _getLabelTypeName(dynamic item) {
    if (item is FGPalletLabel) return 'FG Pallet Labels';
    if (item is RollLabel) return 'Roll Labels';
    if (item is FGLocationLabel) return 'FG Location Labels';
    return 'Paper Roll Location Labels';
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isExporting ? null : _exportData,
      icon: widget.showIcon
          ? _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download)
          : const SizedBox.shrink(),
      label: Text(_isExporting ? 'Exporting...' : 'Export'),
    );
  }
}