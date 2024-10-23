import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/export_to_csv_button.dart';
import 'package:flutter/material.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  final ScanService _scanService = ScanService();
  LabelType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScanSession>>(
      stream: _scanService.sessionsStream,
      initialData: _scanService.sessions,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No scan history'));
        }

        final sessions = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<LabelType?>(
                value: _selectedType,
                hint: const Text('Filter by type'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...LabelType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(_getLabelTypeName(type)),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, sessionIndex) {
                  final session = sessions[sessionIndex];
                  final filteredScans = _getFilteredScans(session);

                  if (filteredScans.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ExpansionTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Session ${sessionIndex + 1}'),
                          if (session == _scanService.currentSession)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Chip(
                                label: Text('Current'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                            ),
                          const ExportToCsvButton()
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Started: ${session.startTime.toString()}'),
                          Text('Scans: ${_getSessionScanCounts(session)}'),
                        ],
                      ),
                      children: filteredScans.map((scan) => ListTile(
                        title: Text(_getScanDisplayText(scan)),
                        subtitle: Text('Time: ${scan.timeLog}'),
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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

  List<dynamic> _getFilteredScans(ScanSession session) {
    if (_selectedType == null) return session.scans;
    
    return session.scans.where((scan) {
      switch (_selectedType!) {
        case LabelType.fgPallet:
          return scan is FGPalletLabel;
        case LabelType.roll:
          return scan is RollLabel;
        case LabelType.fgLocation:
          return scan is FGLocationLabel;
        case LabelType.paperRollLocation:
          return scan is PaperRollLocationLabel;
        default:
          return false;
      }
    }).toList();
  }

  String _getScanDisplayText(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'FG Pallet - PLT#: ${scan.plateId}, WO: ${scan.workOrder}';
    }
    if (scan is RollLabel) {
      return 'Roll - ID: ${scan.rollId}';
    }
    if (scan is FGLocationLabel) {
      return 'FG Location - ID: ${scan.locationId}';
    }
    if (scan is PaperRollLocationLabel) {
      return 'Paper Roll Location - ID: ${scan.locationId}';
    }
    return 'Unknown Type';
  }

  String _getSessionScanCounts(ScanSession session) {
    if (_selectedType != null) {
      return '${session.scanCounts[_selectedType!]} ${_getLabelTypeName(_selectedType!)}';
    }
    
    return session.scanCounts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value} ${_getLabelTypeName(e.key)}')
        .join(', ');
  }
}