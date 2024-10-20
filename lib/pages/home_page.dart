import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final ScanService _scanService = ScanService();

  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScanSession>>(
      stream: _scanService.sessionsStream,
      initialData: _scanService.sessions,
      builder: (context, snapshot){
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
            ],
          )
        );
      }
    );
  }
  Widget _buildLabelTypeSection(
    String title,
    LabelType type,
    String Function(dynamic) getDisplayText,
  ){
    final scans = _scanService.getScansOfType(type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if(scans.isEmpty)
              const Text('No scans yet')
            else
              ...scans.map((scan) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getDisplayText(scan),
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Scanned: ${scan.timeLog.toString()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const Divider(),
                  ],
                )
              ))
          ],
        )
      ),
    );
  }
}