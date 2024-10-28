import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class FGPalletLabel extends BaseLabel {
  final String plateId;
  final String workOrder;
  final String rawValue;

  FGPalletLabel({
    required this.plateId,
    required this.workOrder,
    required DateTime checkIn,
    required this.rawValue,
    Map<String, dynamic>? metadata,
  }) : super(
    checkIn: checkIn,
    metadata: metadata,
  );

  // Parse the scanned value into FGPalletLabel object
  static FGPalletLabel? fromScanData(String scanData) {
    // Check if the format matches FG Pallet Label pattern
    if (scanData.length != 23 || !scanData.contains('-')) return null;

    try {
      final plateId = scanData.substring(0, 11); // 2410-000008
      final workOrder = '${scanData.substring(12, 14)}-${scanData.substring(14, 18)}-${scanData.substring(18)}'; // 10-2024-00047

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

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'plate_id': plateId,
      'work_order': workOrder,
      'raw_value': rawValue,
    };
  }

  factory FGPalletLabel.fromMap(Map<String, dynamic> data) {
    return FGPalletLabel(
      plateId: data['plate_id'],
      workOrder: data['work_order'],
      rawValue: data['raw_value'],
      checkIn: DateTime.parse(data['check_in']),
      metadata: data['metadata'],
    );
  }
}