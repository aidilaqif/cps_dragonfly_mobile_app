import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';

class ScanSession {
  final String sessionId;
  final DateTime startTime;
  final List<dynamic> scans; // Can contain various label types
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

  factory ScanSession.fromMap(Map<String, dynamic> data) {
    return ScanSession(
      sessionId: data['session_id'],
      startTime: DateTime.parse(data['start_time']),
      scans: data['scans'], // Handle conversion appropriately
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'start_time': startTime.toIso8601String(),
      'scans': scans, // Handle serialization appropriately
    };
  }
}
