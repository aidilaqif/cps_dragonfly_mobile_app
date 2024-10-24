class RollLabel {
  final String rollId;
  final DateTime timeLog;

  RollLabel({
    required this.rollId,
    required this.timeLog,
  });

  // Parse the scanned value into RollLabel object
  static RollLabel? fromScanData(String scanData) {
    // Check if the format matches Roll Label pattern (8 characters)
    if (scanData.length != 8) return null;

    // Check if it follows the pattern: 2 digits + 1 letter + 5 digits
    final pattern = RegExp(r'^\d{2}[A-Z]\d{5}$');
    if (!pattern.hasMatch(scanData)) return null;

    return RollLabel(
      rollId: scanData,
      timeLog: DateTime.now(),
    );
  }

  factory RollLabel.fromMap(Map<String, dynamic> data) {
    return RollLabel(
      rollId: data['roll_id'],
      timeLog: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roll_id': rollId,
      'created_at': timeLog.toIso8601String(),
    };
  }
}