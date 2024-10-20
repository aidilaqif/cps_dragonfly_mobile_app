import 'dart:async';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
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

  bool processScannedCode(String value){
    if(_currentSession == null) return false;

    // Try parsing as FG Pallet Label
    final fgPalletLabel = FGPalletLabel.fromScanData(value);
    if(fgPalletLabel != null){
      // Check if this plate ID already exists in current session
      if(isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(fgPalletLabel, LabelType.fgPallet);
      _sessionController.add(_sessions);
      return true;
    }
    // Try parsing as Roll Label
    final rollLabel = RollLabel.fromScanData(value);
    if(rollLabel != null){
      // Check if this roll ID already exist in current session
      if(isValueExistsInCurrentSession(value)) return false;

      _currentSession!.addScan(rollLabel, LabelType.roll);
      _sessionController.add(_sessions);
      return true;
    }
    return false; // Unknown format
  }

  bool isValueExistsInCurrentSession(String value) {
    if (_currentSession == null) return false;

    return _currentSession!.scans.any((scan) {
      if (scan is FGPalletLabel) return scan.rawValue == value;
      if (scan is RollLabel) return scan.rollId == value;
      return false;
    });
  }

  bool isValueExistsInOtherSessions(String value) {
    return _sessions
        .where((session) => session != _currentSession)
        .any((session) => session.scans.any((scan) {
              if (scan is FGPalletLabel) return scan.rawValue == value;
              if (scan is RollLabel) return scan.rollId == value;
              return false;
            }));
  }
  void endCurrentSession(){
    _currentSession = null;
  }

  List<dynamic> getScansOfType(LabelType type){
    return _sessions.expand((session) => session.scans).where((scan){
      switch (type){
        case LabelType.fgPallet:
          return scan is FGPalletLabel;
        case LabelType.roll:
          return scan is RollLabel;
        default:
          return false;
      }
    }).toList();
  }
  // bool addScan(String value, String type){
  //   if(_currentSession == null){
  //     return false;
  //   }
  //   //To check if the value exists in current sessions
  //   bool existsInCurrentSession = _currentSession!.scans.any((scan)=> scan.value == value);
  //   if(existsInCurrentSession){
  //     return false;
  //   }

  //   final scan = ScanResult(
  //     value: value,
  //     type: type,
  //     timelog: DateTime.now(),
  //   );

  //   _currentSession!.scans.add(scan);
  //   _sessionController.add(_sessions);
  //   return true;
  // }
  // bool isValueExistsInCurrentSession(String value){
  //   if(_currentSession == null) return false;
  //   return _currentSession!.scans.any((scan) => scan.value == value);
  // }
  // bool isValueExistsInOtherSessions(String value){
  //   return _sessions.where((session) => session != _currentSession).any((session) => session.scans.any((scan)=> scan.value == value));
  // }
}