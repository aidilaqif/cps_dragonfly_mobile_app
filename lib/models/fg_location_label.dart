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
     // Pattern matches:
    // - Single letter B
    // - B followed by 2 digits (B01)
    // - A followed by 2 digits (A07, A08)
    // - RA or RB followed by 1 digit (RA1, RB4)
    // final pattern = RegExp(r'^(B|B\d{2}|A\d{2}|R[AB][1-5])$');
    if (!pattern.hasMatch(scanData)) return null;

    return FGLocationLabel(
      locationId: scanData, // Convert to uppercase for consistency
      timeLog: DateTime.now(),
    );
  }
}