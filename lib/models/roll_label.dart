import 'base_label.dart';

class RollLabel extends BaseLabel {
  final String rollId;

  RollLabel({
    required this.rollId,
    required DateTime checkIn,
    Map<String, dynamic>? metadata,
    String? status,
    DateTime? statusUpdatedAt,
    String? statusNotes,
  }) : super(
          checkIn: checkIn,
          metadata: metadata,
          status: status,
          statusUpdatedAt: statusUpdatedAt,
          statusNotes: statusNotes,
        );

  // Add getters for batch and sequence
  String get batchNumber => rollId.length >= 2 ? rollId.substring(0, 2) : '';
  String get sequenceNumber => rollId.length > 3 ? rollId.substring(3) : '';

  factory RollLabel.fromMap(Map<String, dynamic> data) {
    print('Creating RollLabel from data: $data'); // Debug log
    return RollLabel(
      rollId: data['roll_id'] ?? '',
      checkIn:
          DateTime.parse(data['check_in'] ?? DateTime.now().toIso8601String()),
      status: data['status'],
      statusUpdatedAt: data['status_updated_at'] != null
          ? DateTime.parse(data['status_updated_at'])
          : null,
      statusNotes: data['status_notes'],
      metadata: data['metadata'],
    );
  }

  static RollLabel? fromScanData(String scanData) {
    if (scanData.length != 8) return null;

    final pattern = RegExp(r'^\d{2}[A-Z]\d{5}$');
    if (!pattern.hasMatch(scanData)) return null;

    return RollLabel(
      rollId: scanData,
      checkIn: DateTime.now(),
    );
  }
}
