import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';

class ScanSession {
  final String sessionId;
  final DateTime startTime;
  final List<dynamic> scans; // Can contain FGPalletLabel or RollLabel objects
  final Map<LabelType, int> scanCounts;

  ScanSession({
    required this.sessionId,
    required this.startTime,
    List<dynamic>? scans,
  }) : 
    scans = scans ?? [],
    scanCounts = {
      for (var type in LabelType.values) type: 0
    };

  void addScan(dynamic scan, LabelType type) {
    scans.add(scan);
    scanCounts[type] = (scanCounts[type] ?? 0) + 1;
  }
}