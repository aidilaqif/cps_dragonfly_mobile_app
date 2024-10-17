import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:flutter/material.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  final ScanService _scanService = ScanService();
  String? _selectedType;

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
              child: DropdownButton<String>(
                value: _selectedType,
                hint: const Text('Filter by type'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'qrCode', child: Text('QR Code')),
                  DropdownMenuItem(value: 'barcode', child: Text('Barcode')),
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
                  final filteredScans = _selectedType == null
                      ? session.scans
                      : session.scans.where((scan) => scan.type == _selectedType).toList();

                  if (filteredScans.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ExpansionTile(
                      title: Row(
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
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Started: ${session.startTime.toString()}'),
                          Text('Scans: ${filteredScans.length}'),
                        ],
                      ),
                      children: filteredScans.map((scan) => ListTile(
                        title: Text(scan.value),
                        subtitle: Text('Type: ${scan.type}\nTime: ${scan.timelog}'),
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
}