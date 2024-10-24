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
        'INSERT INTO sessions (start_time) VALUES (@startTime) RETURNING id, start_time',
        substitutionValues: {
          'startTime': DateTime.now().toUtc(),
        }
      );
      
      final sessionId = result.first[0] as int;
      final startTime = result.first[1] is String 
          ? DateTime.parse(result.first[1] as String).toLocal()
          : (result.first[1] as DateTime).toLocal();

      _currentSession = ScanSession(
        sessionId: sessionId.toString(),
        startTime: startTime,
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
        SELECT id, start_time, end_time
        FROM sessions
        ORDER BY start_time DESC
      ''');

      _sessions.clear(); // Clear existing sessions

      for (final sessionRow in sessions) {
        final sessionId = sessionRow[0] as int;
        final startTime = sessionRow[1] is String 
            ? DateTime.parse(sessionRow[1] as String).toLocal()
            : (sessionRow[1] as DateTime).toLocal();

        final session = ScanSession(
          sessionId: sessionId.toString(),
          startTime: startTime,
        );

        // Fetch all labels for this session
        final labels = await _connection.query('''
          SELECT 
            l.id,
            l.label_type,
            l.scan_time,
            l.is_rescan,
            fpl.plate_id,
            fpl.work_order,
            rl.roll_id,
            fl.location_id as fg_location_id,
            prl.location_id as paper_roll_location_id
          FROM labels l
          LEFT JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
          LEFT JOIN roll_labels rl ON l.id = rl.label_id
          LEFT JOIN fg_location_labels fl ON l.id = fl.label_id
          LEFT JOIN paper_roll_location_labels prl ON l.id = prl.label_id
          WHERE l.session_id = @sessionId
          ORDER BY l.scan_time
        ''', substitutionValues: {'sessionId': sessionId});

        for (final labelRow in labels) {
          final labelType = labelRow[1] as String;
          final scanTime = labelRow[2] is String 
              ? DateTime.parse(labelRow[2] as String).toLocal()
              : (labelRow[2] as DateTime).toLocal();
          final isRescan = labelRow[3] as bool;

          dynamic label;
          LabelType type;

          switch (labelType) {
            case 'fg_pallet':
              label = FGPalletLabel(
                plateId: labelRow[4] as String,
                workOrder: labelRow[5] as String,
                timeLog: scanTime,
                rawValue: '${labelRow[4]}-${labelRow[5]}',
              );
              type = LabelType.fgPallet;
              break;

            case 'roll':
              label = RollLabel(
                rollId: labelRow[6] as String,
                timeLog: scanTime,
              );
              type = LabelType.roll;
              break;

            case 'fg_location':
              label = FGLocationLabel(
                locationId: labelRow[7] as String,
                timeLog: scanTime,
              );
              type = LabelType.fgLocation;
              break;

            case 'paper_roll_location':
              label = PaperRollLocationLabel(
                locationId: labelRow[8] as String,
                timeLog: scanTime,
              );
              type = LabelType.paperRollLocation;
              break;

            default:
              continue;
          }

          session.addScan(label, type);
        }

        _sessions.add(session);
      }

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
      }
    }).toList();
  }

  bool addScan(String value) {
    if (_currentSession == null) return false;

    // Try parsing as FG Pallet Label
    final fgPalletLabel = FGPalletLabel.fromScanData(value);
    if (fgPalletLabel != null) {
      if (isValueExistsInCurrentSession(value)) return false;
      _currentSession!.addScan(fgPalletLabel, LabelType.fgPallet);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as Roll Label
    final rollLabel = RollLabel.fromScanData(value);
    if (rollLabel != null) {
      if (isValueExistsInCurrentSession(value)) return false;
      _currentSession!.addScan(rollLabel, LabelType.roll);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as FG Location Label
    final fgLocationLabel = FGLocationLabel.fromScanData(value);
    if (fgLocationLabel != null) {
      if (isValueExistsInCurrentSession(value)) return false;
      _currentSession!.addScan(fgLocationLabel, LabelType.fgLocation);
      _sessionController.add(_sessions);
      return true;
    }

    // Try parsing as Paper Roll Location Label
    final paperRollLocationLabel = PaperRollLocationLabel.fromScanData(value);
    if (paperRollLocationLabel != null) {
      if (isValueExistsInCurrentSession(value)) return false;
      _currentSession!.addScan(paperRollLocationLabel, LabelType.paperRollLocation);
      _sessionController.add(_sessions);
      return true;
    }

    return false;
  }
}