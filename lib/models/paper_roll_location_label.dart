class PaperRollLocationLabel {
  final String locationId;
  final DateTime timeLog;

  PaperRollLocationLabel({
    required this.locationId,
    required this.timeLog,
  });

  // Parse the scanned value into PaperRollLocationLabel object
  static PaperRollLocationLabel? fromScanData(String scanData) {
    // Pattern matches: any letter followed by a number
    // Example: A1, B2, C3, S3, P2, X9, etc.
    // final pattern = RegExp(r'^[A-Za-z][0-9]$');
    // Pattern matches: S followed by a number, or P followed by a number
    final pattern = RegExp(r'^[A-Z][0-9]$');
    if (!pattern.hasMatch(scanData)) return null;

    return PaperRollLocationLabel(
      locationId: scanData, // Convert to uppercase for consistency
      timeLog: DateTime.now(),
    );
  }
}