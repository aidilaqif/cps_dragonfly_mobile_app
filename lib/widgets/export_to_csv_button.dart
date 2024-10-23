import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/csv_export_service.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_session_service.dart'; // Use the correct service
import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    // Create the PostgreSQL connection using .env variables
    final connection = PostgreSQLConnection(
      dotenv.env['DB_HOST'] ?? '',
      int.parse(dotenv.env['DB_PORT'] ?? '5432'),
      dotenv.env['DB_DATABASE'] ?? '',
      username: dotenv.env['DB_USERNAME'] ?? '',
      password: dotenv.env['DB_PASSWORD'] ?? '',
    );

    // Open the connection
    await connection.open();
    final scanSessionService = ScanSessionService(connection);

    // Fetch sessions dynamically if not provided
    List<ScanSession> sessionsToExport = sessions ?? await scanSessionService.fetchSessions();

    final filePath = await service.exportToExcel(
      sessions: sessionsToExport,
      filterTypes: filterTypes,
      sessionIndex: sessionIndex,
    );

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Scan Data Export',
    );

    // Close the connection
    await connection.close();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error exporting data: ${e.toString()}')),
    );
  }
}
}