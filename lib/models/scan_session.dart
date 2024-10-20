import 'package:cps_dragonfly_4_mobile_app/models/scan_result.dart';

class ScanSession{
  final String sessionId;
  final DateTime startTime;
  final List<ScanResult> scans;
  
  ScanSession({
    required this.sessionId,
    required this.startTime,
    required this.scans
  });
}