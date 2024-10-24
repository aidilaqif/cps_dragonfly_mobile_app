class PaperRollLocationLabel {
  final String locationId;
  final DateTime timeLog;

  PaperRollLocationLabel({
    required this.locationId,
    required this.timeLog,
  });

  // Parse the scanned value into PaperRollLocationLabel object
  static PaperRollLocationLabel? fromScanData(String scanData) {
    final pattern = RegExp(r'^[A-Z][0-9]$');
    if (!pattern.hasMatch(scanData)) return null;

    return PaperRollLocationLabel(
      locationId: scanData, // Convert to uppercase for consistency
      timeLog: DateTime.now(),
    );
  }

  factory PaperRollLocationLabel.fromMap(Map<String, dynamic> data) {
    return PaperRollLocationLabel(
      locationId: data['location_id'],
      timeLog: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location_id': locationId,
      'created_at': timeLog.toIso8601String(),
    };
  }
}
