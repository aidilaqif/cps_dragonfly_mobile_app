import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/csv_export_service.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ExportToCsvButton extends StatelessWidget {
  final List<ScanSession>? sessions;
  final List<LabelType>? filterTypes;
  final int? sessionIndex;
  final bool showIcon;

  const ExportToCsvButton({
    super.key,
    this.sessions,
    this.filterTypes,
    this.sessionIndex,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _exportData(context),
      icon: showIcon ? const Icon(Icons.download) : const SizedBox.shrink(),
      label: const Text("Export to CSV"),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final service = CsvExportService();
      final filePath = await service.exportToExcel(
        sessions: sessions ?? ScanService().sessions,
        filterTypes: filterTypes,
        sessionIndex: sessionIndex,
      );
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Scan Data Export',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting data: ${e.toString()}')),
      );
    }
  }
}