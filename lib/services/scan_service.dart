import 'dart:async';
import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/scan_session.dart';

class ScanService{
  static final ScanService _instance = ScanService._internal();
  factory ScanService() => _instance;
  ScanService._internal();

  final List<ScanSession> _sessions = [];
  ScanSession? _currentSession;
  final _sessionController = StreamController<List<ScanSession>>.broadcast();

  Stream<List<ScanSession>> get sessionsStream => _sessionController.stream;
  List<ScanSession> get sessions => _sessions;
  ScanSession? get currentSession => _currentSession;

  void startNewSession(){
    _currentSession = ScanSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      scans: [],
    );
    _sessions.add(_currentSession!);
    _sessionController.add(_sessions);
  }

  void continueLastSession(){
    if(_sessions.isNotEmpty){
      _currentSession = _sessions.last;
    }else{
      startNewSession();
    }
  }
  bool addScan(String value){
    if (_currentSession == null) return false;

    // Try parsing as FG Pallet Label
    final fgPalletLabel = FGPalletLabel.fromScanData(value);
    if (fgPalletLabel != null) {
      // Check if this plate ID already exists in current session
      if (isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(fgPalletLabel, LabelType.fgPallet);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as Roll Label
    final rollLabel = RollLabel.fromScanData(value);
    if (rollLabel != null) {
      // Check if this roll ID already exists in current session
      if (isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(rollLabel, LabelType.roll);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as FG Location Label
    final fgLocationLabel = FGLocationLabel.fromScanData(value);
    if (fgLocationLabel != null) {
      // Check if this location ID already exists in current session
      if (isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(fgLocationLabel, LabelType.fgLocation);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as Paper Roll Location Label
    final paperRollLocationLabel = PaperRollLocationLabel.fromScanData(value);
    if (paperRollLocationLabel != null) {
      // Check if this location ID already exists in current session
      if (isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(paperRollLocationLabel, LabelType.paperRollLocation);
      _sessionController.add(_sessions);
      return true;
    }
    return false; // Unknown
  }
  void endCurrentSession(){
    _currentSession = null;
  }
  bool isValueExistsInCurrentSession(String value){
    if(_currentSession == null) return false;
    return _currentSession!.scans.any((scan) {
      if (scan is FGPalletLabel) return scan.rawValue == value;
      if (scan is RollLabel) return scan.rollId == value;
      if (scan is FGLocationLabel) return scan.locationId == value;
      if (scan is PaperRollLocationLabel) return scan.locationId == value;
      return false;
    });
  }
  bool isValueExistsInOtherSessions(String value){
    return _sessions
        .where((session) => session != _currentSession)
        .any((session) => session.scans.any((scan) {
              if (scan is FGPalletLabel) return scan.rawValue == value;
              if (scan is RollLabel) return scan.rollId == value;
              if (scan is FGLocationLabel) return scan.locationId == value;
              if (scan is PaperRollLocationLabel) return scan.locationId == value;
              return false;
            }));
  }
  List<dynamic> getScansOfType(LabelType type) {
    return _sessions.expand((session) => session.scans).where((scan) {
      switch (type) {
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
}