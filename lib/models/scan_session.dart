import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';

class ScanSession {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<dynamic> scans; // All scans (both new and rescans)
  final List<dynamic> newScans; // Only new scans
  final List<dynamic> rescans; // Only rescans
  final Map<LabelType, int> scanCounts;
  final Map<LabelType, int> newScanCounts;
  final Map<LabelType, int> rescanCounts;
  
  int newScansCount;
  int rescanCount;

  ScanSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    List<dynamic>? scans,
    this.newScansCount = 0,
    this.rescanCount = 0,
  }) : 
    scans = scans ?? [],
    newScans = [],
    rescans = [],
    scanCounts = {
      for (var type in LabelType.values) type: 0
    },
    newScanCounts = {
      for (var type in LabelType.values) type: 0
    },
    rescanCounts = {
      for (var type in LabelType.values) type: 0
    };

  void addScan(dynamic scan, LabelType type) {
    scans.add(scan);
    scanCounts[type] = (scanCounts[type] ?? 0) + 1;
  }

  void addNewScan(dynamic scan, LabelType type) {
    scans.add(scan);
    newScans.add(scan);
    scanCounts[type] = (scanCounts[type] ?? 0) + 1;
    newScanCounts[type] = (newScanCounts[type] ?? 0) + 1;
    newScansCount++;
  }

  void addRescan(dynamic scan, LabelType type) {
    scans.add(scan);
    rescans.add(scan);
    scanCounts[type] = (scanCounts[type] ?? 0) + 1;
    rescanCounts[type] = (rescanCounts[type] ?? 0) + 1;
    rescanCount++;
  }

  bool hasScannedValue(String value) {
    return scans.any((scan) {
      if (scan is dynamic && scan.toString() == value) return true;
      
      // Check specific label types
      try {
        if (scan.rawValue == value) return true; // For FG Pallet Labels
        if (scan.rollId == value) return true; // For Roll Labels
        if (scan.locationId == value) return true; // For Location Labels
      } catch (_) {
        // Ignore any property access errors
      }
      
      return false;
    });
  }

  DateTime? getFirstScanTime(String value) {
    DateTime? firstScan;
    
    for (var scan in scans) {
      if (_matchesScanValue(scan, value)) {
        final scanTime = scan.timeLog;
        if (firstScan == null || scanTime.isBefore(firstScan)) {
          firstScan = scanTime;
        }
      }
    }
    
    return firstScan;
  }

  bool _matchesScanValue(dynamic scan, String value) {
    try {
      if (scan.rawValue == value) return true; // For FG Pallet Labels
      if (scan.rollId == value) return true; // For Roll Labels
      if (scan.locationId == value) return true; // For Location Labels
    } catch (_) {
      // Ignore any property access errors
    }
    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'new_scans_count': newScansCount,
      'rescan_count': rescanCount,
      'scans': scans.map((scan) => scan.toMap()).toList(),
    };
  }

  factory ScanSession.fromMap(Map<String, dynamic> data) {
    return ScanSession(
      sessionId: data['session_id'],
      startTime: DateTime.parse(data['start_time']),
      endTime: data['end_time'] != null ? DateTime.parse(data['end_time']) : null,
      newScansCount: data['new_scans_count'] ?? 0,
      rescanCount: data['rescan_count'] ?? 0,
    );
  }

  // Statistics methods
  Map<LabelType, int> getTypeStats({bool newOnly = false, bool rescanOnly = false}) {
    if (newOnly) return Map.from(newScanCounts);
    if (rescanOnly) return Map.from(rescanCounts);
    return Map.from(scanCounts);
  }

  List<dynamic> getScansByType(LabelType type, {bool newOnly = false, bool rescanOnly = false}) {
    if (newOnly) {
      return newScans.where((scan) => _getScanType(scan) == type).toList();
    }
    if (rescanOnly) {
      return rescans.where((scan) => _getScanType(scan) == type).toList();
    }
    return scans.where((scan) => _getScanType(scan) == type).toList();
  }

  LabelType? _getScanType(dynamic scan) {
    try {
      if (scan.runtimeType.toString().contains('FGPalletLabel')) return LabelType.fgPallet;
      if (scan.runtimeType.toString().contains('RollLabel')) return LabelType.roll;
      if (scan.runtimeType.toString().contains('FGLocationLabel')) return LabelType.fgLocation;
      if (scan.runtimeType.toString().contains('PaperRollLocationLabel')) return LabelType.paperRollLocation;
    } catch (_) {
      // Ignore any errors in type checking
    }
    return null;
  }

  // Utility methods
  bool get isActive => endTime == null;
  Duration get duration => endTime?.difference(startTime) ?? DateTime.now().difference(startTime);
  int get totalScans => newScansCount + rescanCount;
  double get rescanPercentage => totalScans > 0 ? (rescanCount / totalScans) * 100 : 0;

  // Time-based query methods
  List<dynamic> getScansInTimeRange(DateTime start, DateTime end) {
    return scans.where((scan) {
      final scanTime = scan.timeLog;
      return scanTime.isAfter(start) && scanTime.isBefore(end);
    }).toList();
  }

  // Analysis methods
  Map<String, int> getRescanFrequency() {
    Map<String, int> frequency = {};
    for (var scan in scans) {
      final value = _getScanValue(scan);
      if (value != null) {
        frequency[value] = (frequency[value] ?? 0) + 1;
      }
    }
    return Map.fromEntries(
      frequency.entries.where((e) => e.value > 1)
    );
  }

  String? _getScanValue(dynamic scan) {
    try {
      if (scan.rawValue != null) return scan.rawValue; // For FG Pallet Labels
      if (scan.rollId != null) return scan.rollId; // For Roll Labels
      if (scan.locationId != null) return scan.locationId; // For Location Labels
    } catch (_) {
      // Ignore any property access errors
    }
    return null;
  }
}