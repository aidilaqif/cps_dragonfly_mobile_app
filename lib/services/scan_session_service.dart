import 'dart:async';
import 'package:postgres/postgres.dart';
import '../models/fg_location_label.dart';
import '../models/fg_pallet_label.dart';
import '../models/label_types.dart';
import '../models/paper_roll_location_label.dart';
import '../models/roll_label.dart';
import '../models/scan_session.dart';

class ScanSessionService {
  static final ScanSessionService _instance = ScanSessionService._internal();
  factory ScanSessionService(PostgreSQLConnection connection) {
    _instance._connection = connection;
    return _instance;
  }
  ScanSessionService._internal();

  late PostgreSQLConnection _connection;
  final List<ScanSession> _sessions = [];
  ScanSession? _currentSession;
  final _sessionController = StreamController<List<ScanSession>>.broadcast();

  Stream<List<ScanSession>> get sessionsStream => _sessionController.stream;
  List<ScanSession> get sessions => _sessions;
  ScanSession? get currentSession => _currentSession;

  Future<void> startNewSession() async {
    try {
      final result = await _connection.query(
        '''
        WITH new_session AS (
          INSERT INTO sessions (start_time) 
          VALUES (@startTime) 
          RETURNING id, start_time
        )
        SELECT 
          ns.id, 
          ns.start_time,
          COALESCE(
            (SELECT COUNT(*) FROM labels l WHERE l.session_id = ns.id AND l.is_rescan = false),
            0
          ) as new_scans,
          COALESCE(
            (SELECT COUNT(*) FROM labels l WHERE l.session_id = ns.id AND l.is_rescan = true),
            0
          ) as rescans
        FROM new_session ns
        ''',
        substitutionValues: {
          'startTime': DateTime.now().toUtc(),
        }
      );
      
      final sessionId = result.first[0] as int;
      final startTime = result.first[1] is String 
          ? DateTime.parse(result.first[1] as String).toLocal()
          : (result.first[1] as DateTime).toLocal();
      final newScans = result.first[2] as int;
      final rescans = result.first[3] as int;

      _currentSession = ScanSession(
        sessionId: sessionId.toString(),
        startTime: startTime,
        newScansCount: newScans,
        rescanCount: rescans,
      );
      _sessions.add(_currentSession!);
      _sessionController.add(_sessions);
    } catch (e) {
      print('Error starting new session: $e');
      throw Exception('Failed to start new session: $e');
    }
  }

  Future<List<ScanSession>> fetchSessions() async {
    try {
      final sessions = await _connection.query('''
        WITH session_stats AS (
          SELECT 
            s.id,
            s.start_time,
            s.end_time,
            COUNT(CASE WHEN l.is_rescan = false THEN 1 END) as new_scans,
            COUNT(CASE WHEN l.is_rescan = true THEN 1 END) as rescans
          FROM sessions s
          LEFT JOIN labels l ON s.id = l.session_id
          GROUP BY s.id, s.start_time, s.end_time
        )
        SELECT 
          ss.*,
          l.id as label_id,
          l.label_type,
          l.scan_time,
          l.is_rescan,
          fpl.plate_id,
          fpl.work_order,
          rl.roll_id,
          fl.location_id as fg_location_id,
          prl.location_id as paper_roll_location_id
        FROM session_stats ss
        LEFT JOIN labels l ON ss.id = l.session_id
        LEFT JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        LEFT JOIN roll_labels rl ON l.id = rl.label_id
        LEFT JOIN fg_location_labels fl ON l.id = fl.label_id
        LEFT JOIN paper_roll_location_labels prl ON l.id = prl.label_id
        ORDER BY ss.start_time DESC, l.scan_time DESC
      ''');

      _sessions.clear();
      
      Map<int, ScanSession> sessionsMap = {};

      for (final row in sessions) {
        final sessionId = row[0] as int;
        
        if (!sessionsMap.containsKey(sessionId)) {
          final startTime = row[1] is String 
              ? DateTime.parse(row[1] as String).toLocal()
              : (row[1] as DateTime).toLocal();
          final endTime = row[2] != null 
              ? (row[2] is String 
                  ? DateTime.parse(row[2] as String).toLocal()
                  : (row[2] as DateTime).toLocal())
              : null;
          final newScans = row[3] as int;
          final rescans = row[4] as int;

          sessionsMap[sessionId] = ScanSession(
            sessionId: sessionId.toString(),
            startTime: startTime,
            endTime: endTime,
            newScansCount: newScans,
            rescanCount: rescans,
          );
        }

        // Add scan if it exists
        if (row[5] != null) { // label_id
          final labelType = row[6] as String;
          final scanTime = row[7] is String 
              ? DateTime.parse(row[7] as String).toLocal()
              : (row[7] as DateTime).toLocal();
          final isRescan = row[8] as bool;

          dynamic label;
          LabelType type;

          switch (labelType) {
            case 'fg_pallet':
              final plateId = row[9] as String;
              final workOrder = row[10] as String;
              label = FGPalletLabel(
                plateId: plateId,
                workOrder: workOrder,
                timeLog: scanTime,
                rawValue: '$plateId-$workOrder',
              );
              type = LabelType.fgPallet;
              break;

            case 'roll':
              label = RollLabel(
                rollId: row[11] as String,
                timeLog: scanTime,
              );
              type = LabelType.roll;
              break;

            case 'fg_location':
              label = FGLocationLabel(
                locationId: row[12] as String,
                timeLog: scanTime,
              );
              type = LabelType.fgLocation;
              break;

            case 'paper_roll_location':
              label = PaperRollLocationLabel(
                locationId: row[13] as String,
                timeLog: scanTime,
              );
              type = LabelType.paperRollLocation;
              break;

            default:
              continue;
          }

          final session = sessionsMap[sessionId]!;
          if (!isRescan) {
            session.addNewScan(label, type);
          } else {
            session.addRescan(label, type);
          }
        }
      }

      _sessions.addAll(sessionsMap.values);

      // Update current session if it exists
      if (_currentSession != null) {
        final currentSessionIndex = _sessions.indexWhere(
          (s) => s.sessionId == _currentSession!.sessionId
        );
        if (currentSessionIndex != -1) {
          _currentSession = _sessions[currentSessionIndex];
        }
      }

      _sessionController.add(_sessions);
      return _sessions;
    } catch (e) {
      print('Error fetching sessions: $e');
      throw Exception('Failed to fetch sessions: $e');
    }
  }

  void continueLastSession() {
    if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
    } else {
      startNewSession();
    }
  }

  Future<void> endCurrentSession() async {
    if (_currentSession != null) {
      try {
        await _connection.query(
          'UPDATE sessions SET end_time = @endTime WHERE id = @sessionId',
          substitutionValues: {
            'endTime': DateTime.now().toUtc(),
            'sessionId': int.parse(_currentSession!.sessionId),
          }
        );
        _currentSession = null;
      } catch (e) {
        print('Error ending session: $e');
        throw Exception('Failed to end session: $e');
      }
    }
  }

  Future<bool> isRescan(String value, LabelType type) async {
    try {
      String query;
      Map<String, dynamic> substitutionValues = {'value': value};

      switch (type) {
        case LabelType.fgPallet:
          query = '''
            SELECT EXISTS (
              SELECT 1 
              FROM labels l
              JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
              WHERE CONCAT(fpl.plate_id, '-', fpl.work_order) = @value
            )
          ''';
          break;
          
        case LabelType.roll:
          query = '''
            SELECT EXISTS (
              SELECT 1 
              FROM labels l
              JOIN roll_labels rl ON l.id = rl.label_id
              WHERE rl.roll_id = @value
            )
          ''';
          break;
          
        case LabelType.fgLocation:
          query = '''
            SELECT EXISTS (
              SELECT 1 
              FROM labels l
              JOIN fg_location_labels fl ON l.id = fl.label_id
              WHERE fl.location_id = @value
            )
          ''';
          break;
          
        case LabelType.paperRollLocation:
          query = '''
            SELECT EXISTS (
              SELECT 1 
              FROM labels l
              JOIN paper_roll_location_labels prl ON l.id = prl.label_id
              WHERE prl.location_id = @value
            )
          ''';
          break;
      }

      final result = await _connection.query(query, substitutionValues: substitutionValues);
      return result.first[0] as bool;
    } catch (e) {
      print('Error checking rescan status: $e');
      return false;
    }
  }

  bool isValueExistsInCurrentSession(String value) {
    if (_currentSession == null) return false;
    return _currentSession!.scans.any((scan) {
      if (scan is FGPalletLabel) return scan.rawValue == value;
      if (scan is RollLabel) return scan.rollId == value;
      if (scan is FGLocationLabel) return scan.locationId == value;
      if (scan is PaperRollLocationLabel) return scan.locationId == value;
      return false;
    });
  }

  bool isValueExistsInOtherSessions(String value) {
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

  String getPreviousSessionId(String value) {
    for (var session in _sessions) {
      if (session != _currentSession && 
          session.scans.any((scan) {
            if (scan is FGPalletLabel) return scan.rawValue == value;
            if (scan is RollLabel) return scan.rollId == value;
            if (scan is FGLocationLabel) return scan.locationId == value;
            if (scan is PaperRollLocationLabel) return scan.locationId == value;
            return false;
          })) {
        return session.sessionId;
      }
    }
    return '';
  }
}