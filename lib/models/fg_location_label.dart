class FGLocationLabel {
  final String locationId;
  final DateTime timeLog;

  FGLocationLabel({
    required this.locationId,
    required this.timeLog,
  });

  // Parse the scanned value into FGLocationLabel object
  static FGLocationLabel? fromScanData(String scanData) {
    // Pattern matches:
    // - Single letter (like B)
    // - Any letter followed by 2 digits (like B01, A07)
    // - R followed by any letter and a digit 1-5 (like RA1, RB4, RC3)
    final pattern = RegExp(r'^([A-Za-z]|[A-Za-z]\d{2}|R[A-Za-z][1-9])$');
    if (!pattern.hasMatch(scanData)) return null;

    return FGLocationLabel(
      locationId: scanData, // Convert to uppercase for consistency
      timeLog: DateTime.now(),
    );
  }
}