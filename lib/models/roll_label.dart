import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class RollLabel extends BaseLabel {
  final String rollId;

  RollLabel({
    required this.rollId,
    required DateTime timeLog,
    bool isRescan = false,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) : super(
    timeLog: timeLog,
    isRescan: isRescan,
    sessionId: sessionId,
    metadata: metadata,
  );

  String get batchNumber => rollId.substring(0, 2);
  String get sequenceNumber => rollId.substring(3);

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

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'roll_id': rollId,
      'batch_number': batchNumber,
      'sequence_number': sequenceNumber,
    };
  }

  factory RollLabel.fromMap(Map<String, dynamic> data) {
    return RollLabel(
      rollId: data['roll_id'],
      timeLog: DateTime.parse(data['timelog']),
      isRescan: data['is_rescan'] ?? false,
      sessionId: data['session_id'],
      metadata: data['metadata'],
    );
  }
}