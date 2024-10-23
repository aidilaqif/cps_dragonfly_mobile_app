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
}