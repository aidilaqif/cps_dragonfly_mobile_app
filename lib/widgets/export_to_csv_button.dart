import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/csv_export_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:postgres/postgres.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExportToCsvButton extends StatefulWidget {
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
  State<ExportToCsvButton> createState() => _ExportToCsvButtonState();
}

class _ExportToCsvButtonState extends State<ExportToCsvButton> {
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

      final connection = PostgreSQLConnection(
        dotenv.env['DB_HOST'] ?? '',
        int.parse(dotenv.env['DB_PORT'] ?? '5432'),
        dotenv.env['DB_NAME'] ?? '',
        username: dotenv.env['DB_USERNAME'] ?? '',
        password: dotenv.env['DB_PASSWORD'] ?? '',
        useSSL: true,
      );

      await connection.open();

      final service = CsvExportService();
      
      final filePath = await service.exportToExcel(
        sessions: widget.sessions ?? [],
        filterTypes: widget.filterTypes,
        sessionIndex: widget.sessionIndex,
      );

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Scan Data Export',
      );

      await connection.close();

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