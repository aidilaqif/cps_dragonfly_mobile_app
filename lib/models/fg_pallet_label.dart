import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class FGPalletLabel extends BaseLabel {
  final String plateId;
  final String workOrder;
  final String rawValue;

  FGPalletLabel({
    required this.plateId,
    required this.workOrder,
    required this.rawValue,
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

  // Parse the scanned value into FGPalletLabel object
  static FGPalletLabel? fromScanData(String scanData) {
    // Check if the format matches FG Pallet Label pattern
    if (scanData.length != 23 || !scanData.contains('-')) return null;

    try {
      final plateId = scanData.substring(0, 11); // 2410-000008
      final workOrder =
          '${scanData.substring(12, 14)}-${scanData.substring(14, 18)}-${scanData.substring(18)}'; // 10-2024-00047

      return FGPalletLabel(
        rawValue: scanData,
        plateId: plateId,
        workOrder: workOrder,
        checkIn: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  factory FGPalletLabel.fromMap(Map<String, dynamic> data) {
    final label = FGPalletLabel(
      plateId: data['plate_id'] ?? '',
      workOrder: data['work_order'] ?? '',
      rawValue: data['raw_value'] ?? '',
      checkIn:
          DateTime.parse(data['check_in'] ?? DateTime.now().toIso8601String()),
      status: data['status'],
      statusUpdatedAt: data['status_updated_at'] != null
          ? DateTime.parse(data['status_updated_at'])
          : null,
      statusNotes: data['status_notes'],
      metadata: data['metadata'],
    );
    return label;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'plate_id': plateId,
      'work_order': workOrder,
      'raw_value': rawValue,
    };
  }
}
