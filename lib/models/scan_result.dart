class ScanResult {
  final String value;
  final String type;
  final DateTime timelog;
  final bool isRescan;
  final String? originalSessionId; // ID of the session where this was first scanned
  final DateTime? firstScanTime; // When this was first scanned
  final Map<String, dynamic>? metadata; // Additional scan-specific data

  ScanResult({
    required this.value,
    required this.type,
    required this.timelog,
    this.isRescan = false,
    this.originalSessionId,
    this.firstScanTime,
    this.metadata,
  });

  // Parse specific label data into metadata
  static Map<String, dynamic>? _createMetadata(String type, String value) {
    try {
      switch (type) {
        case 'fg_pallet':
          final parts = value.split('-');
          if (parts.length >= 2) {
            return {
              'plate_id': parts[0],
              'work_order': parts.sublist(1).join('-'),
            };
          }
          break;

        case 'roll':
          return {
            'roll_id': value,
            'batch': value.substring(0, 2),
            'sequence': value.substring(2),
          };
          
        case 'fg_location':
          return {
            'location_id': value,
            'area': value.length == 1 ? 'main' : 'sub',
          };
          
        case 'paper_roll_location':
          return {
            'location_id': value,
            'row': value[0],
            'position': value.length > 1 ? value.substring(1) : null,
          };
      }
    } catch (e) {
      print('Error creating metadata: $e');
    }
    return null;
  }

  // Create a new scan result with metadata
  factory ScanResult.withMetadata({
    required String value,
    required String type,
    required DateTime timelog,
    bool isRescan = false,
    String? originalSessionId,
    DateTime? firstScanTime,
  }) {
    return ScanResult(
      value: value,
      type: type,
      timelog: timelog,
      isRescan: isRescan,
      originalSessionId: originalSessionId,
      firstScanTime: firstScanTime,
      metadata: _createMetadata(type, value),
    );
  }

  factory ScanResult.fromMap(Map<String, dynamic> data) {
    return ScanResult(
      value: data['value'],
      type: data['type'],
      timelog: DateTime.parse(data['timelog']),
      isRescan: data['is_rescan'] ?? false,
      originalSessionId: data['original_session_id'],
      firstScanTime: data['first_scan_time'] != null 
          ? DateTime.parse(data['first_scan_time'])
          : null,
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'type': type,
      'timelog': timelog.toIso8601String(),
      'is_rescan': isRescan,
      'original_session_id': originalSessionId,
      'first_scan_time': firstScanTime?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Create a copy with updated values
  ScanResult copyWith({
    String? value,
    String? type,
    DateTime? timelog,
    bool? isRescan,
    String? originalSessionId,
    DateTime? firstScanTime,
    Map<String, dynamic>? metadata,
  }) {
    return ScanResult(
      value: value ?? this.value,
      type: type ?? this.type,
      timelog: timelog ?? this.timelog,
      isRescan: isRescan ?? this.isRescan,
      originalSessionId: originalSessionId ?? this.originalSessionId,
      firstScanTime: firstScanTime ?? this.firstScanTime,
      metadata: metadata ?? this.metadata,
    );
  }

  // Create a rescan version of this result
  ScanResult asRescan({
    required DateTime newTime,
    required String newSessionId,
  }) {
    return ScanResult(
      value: value,
      type: type,
      timelog: newTime,
      isRescan: true,
      originalSessionId: originalSessionId ?? newSessionId,
      firstScanTime: firstScanTime ?? timelog,
      metadata: metadata,
    );
  }

  // Utility methods for type-specific data
  String? get plateId => metadata?['plate_id'];
  String? get workOrder => metadata?['work_order'];
  String? get rollId => metadata?['roll_id'];
  String? get locationId => metadata?['location_id'];
  String? get area => metadata?['area'];
  String? get batch => metadata?['batch'];
  String? get sequence => metadata?['sequence'];
  String? get row => metadata?['row'];
  String? get position => metadata?['position'];

  // Time-based utility methods
  bool get isRecent => DateTime.now().difference(timelog).inHours < 24;
  Duration get age => DateTime.now().difference(timelog);
  Duration? get timeSinceFirstScan => 
      firstScanTime != null ? DateTime.now().difference(firstScanTime!) : null;

  // Validation methods
  bool get isValidFormat {
    switch (type) {
      case 'fg_pallet':
        return value.contains('-') && metadata?['plate_id'] != null;
      case 'roll':
        return value.length == 8 && metadata?['roll_id'] != null;
      case 'fg_location':
        return value.length <= 3 && metadata?['location_id'] != null;
      case 'paper_roll_location':
        return value.length == 2 && metadata?['location_id'] != null;
      default:
        return false;
    }
  }

  // Comparison methods
  bool isSameLabel(ScanResult other) {
    return value == other.value && type == other.type;
  }

  bool isNewerThan(ScanResult other) {
    return timelog.isAfter(other.timelog);
  }

  @override
  String toString() {
    return 'ScanResult('
           'value: $value, '
           'type: $type, '
           'timelog: $timelog, '
           'isRescan: $isRescan, '
           'originalSessionId: $originalSessionId, '
           'metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScanResult &&
           other.value == value &&
           other.type == type &&
           other.timelog == timelog;
  }

  @override
  int get hashCode => Object.hash(value, type, timelog);
}