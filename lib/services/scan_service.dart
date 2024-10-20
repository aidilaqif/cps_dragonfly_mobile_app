import 'dart:async';
import 'package:cps_dragonfly_4_mobile_app/models/scan_result.dart';
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
  bool addScan(String value, String type){
    if(_currentSession == null){
      return false;
    }
    //To check if the value exists in current sessions
    bool existsInCurrentSession = _currentSession!.scans.any((scan)=> scan.value == value);
    if(existsInCurrentSession){
      return false;
    }

    final scan = ScanResult(
      value: value,
      type: type,
      timelog: DateTime.now(),
    );

    _currentSession!.scans.add(scan);
    _sessionController.add(_sessions);
    return true;
  }
  void endCurrentSession(){
    _currentSession = null;
  }
  bool isValueExistsInCurrentSession(String value){
    if(_currentSession == null) return false;
    return _currentSession!.scans.any((scan) => scan.value == value);
  }
  bool isValueExistsInOtherSessions(String value){
    return _sessions.where((session) => session != _currentSession).any((session) => session.scans.any((scan)=> scan.value == value));
  }
}