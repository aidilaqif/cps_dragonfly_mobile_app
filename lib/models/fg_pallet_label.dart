class FGPalletLabel{
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

  // Parse the scanned value into FGPalletLabel Object
  static FGPalletLabel? fromScanData(String scanData){
    // Check if the format matches FG Pallet Label Pattern
    if (scanData.length != 22 || !scanData.contains('-')) return null;

    try{
      final plateId = scanData.substring(0, 11); // 2410-000008
      final workOrder = '${scanData.substring(11, 13)}-${scanData.substring(13, 17)}-${scanData.substring(17)}'; // 10-2024-00047

      return FGPalletLabel(
        rawValue: scanData,
        plateId: plateId,
        workOrder: workOrder,
        timeLog: DateTime.now(),
      );
    }catch(e){
      return null;
    }
  }
}