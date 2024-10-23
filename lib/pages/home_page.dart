import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/export_to_csv_button.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final ScanService _scanService = ScanService();

  HomePage({super.key});

  // Helper method to get unique identifier for each scan type
  String _getUniqueId(dynamic scan){
    if (scan is FGPalletLabel) return scan.plateId;
    if (scan is RollLabel) return scan.rollId;
    if (scan is FGLocationLabel) return scan.locationId;
    if (scan is PaperRollLocationLabel) return scan.locationId;
    return '';
  }

  // Helper method to get the latest scan for each unique item
  List<Map<String, dynamic>> _getLatestUniqueScans(List<dynamic> scans){
    final Map<String, Map<String, dynamic>> uniqueScans = {};

    for (var scan in scans){
      final uniqueId = _getUniqueId(scan);
      if (uniqueId.isEmpty) continue;

      if (!uniqueScans.containsKey(uniqueId) || scan.timeLog.isAfter(uniqueScans[uniqueId]!['scan'].timeLog)){
        //Check if this is a rescan
        final isRescan = uniqueScans.containsKey(uniqueId);
        uniqueScans[uniqueId] = {
          'scan': scan,
          'isRescan': isRescan,
        };
      }
    }
    return uniqueScans.values.toList()
      ..sort((a, b) => b['scan'].timeLog.compareTo(a['scan'].timeLog));
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScanSession>>(
      stream: _scanService.sessionsStream,
      initialData: _scanService.sessions,
      builder: (context, snapshot) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabelTypeSection(
                'FG Pallet Labels',
                LabelType.fgPallet,
                (scan) => 'PLT#: ${(scan as FGPalletLabel).plateId}\nWO: ${scan.workOrder}',
              ),
              const SizedBox(height: 20),
              _buildLabelTypeSection(
                'Roll Labels',
                LabelType.roll,
                (scan) => 'Roll ID: ${(scan as RollLabel).rollId}',
              ),
              const SizedBox(height: 20),
              _buildLabelTypeSection(
                'FG Location Labels',
                LabelType.fgLocation,
                (scan) => 'Location: ${(scan as FGLocationLabel).locationId}',
              ),
              const SizedBox(height: 20),
              _buildLabelTypeSection(
                'Paper Roll Location Labels',
                LabelType.paperRollLocation,
                (scan) => 'Location: ${(scan as PaperRollLocationLabel).locationId}',
              ),
              const SizedBox(height: 20,),
              const Center(
                child: ExportToCsvButton()
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabelTypeSection(
    String title,
    LabelType type,
    String Function(dynamic) getDisplayText,
  ) {
    final scans = _scanService.getScansOfType(type);
    final uniqueScans = _getLatestUniqueScans(scans);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${uniqueScans.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (uniqueScans.isEmpty)
              const Text('No scans yet')
            else
              ...uniqueScans.map((scanData) {
                final scan = scanData['scan'];
                final isRescan = scanData['isRescan'];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                getDisplayText(scan),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (isRescan)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Rescanned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last scan: ${_formatDateTime(scan.timeLog)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime){
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


