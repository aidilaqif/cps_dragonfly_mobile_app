class FGPalletLabel {
  final String rawValue;
  final String plateId;
  final String workOrder;
  final DateTime timeLog;

  FGPalletLabel({
    required this.rawValue,
    required this.plateId,
    required this.workOrder,
    required this.timeLog,
  });

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
        timeLog: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  factory FGPalletLabel.fromMap(Map<String, dynamic> data) {
    return FGPalletLabel(
      rawValue: data['raw_value'],
      plateId: data['plate_id'],
      workOrder: data['work_order'],
      timeLog: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raw_value': rawValue,
      'plate_id': plateId,
      'work_order': workOrder,
      'created_at': timeLog.toIso8601String(),
    };
  }
}
