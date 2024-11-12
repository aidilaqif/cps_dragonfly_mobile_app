import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class PaperRollLocationLabel extends BaseLabel {
  final String locationId;

  PaperRollLocationLabel({
    required this.locationId,
    required DateTime checkIn,
    Map<String, dynamic>? metadata,
  }) : super(
    checkIn: checkIn,
    metadata: metadata,
  );

  String get rowNumber => locationId[0];
  String get positionNumber => locationId[1];

  static PaperRollLocationLabel? fromScanData(String scanData) {
    // Clean the input
    final cleanValue = scanData.trim().toUpperCase();
    print('Paper Roll Location validation for: "$cleanValue"');
    
    // Format: Letter followed by single digit (S3)
    final pattern = RegExp(r'^[A-Z]\d$');
    
    if (!pattern.hasMatch(cleanValue)) {
      print('Paper Roll Location failed validation.');
      print('Must be a letter followed by a single digit (e.g., S3, P2)');
      return null;
    }

    return PaperRollLocationLabel(
      locationId: cleanValue,
      checkIn: DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'location_id': locationId,
      'row_number': rowNumber,
      'position_number': positionNumber,
    };
  }

  factory PaperRollLocationLabel.fromMap(Map<String, dynamic> data) {
    return PaperRollLocationLabel(
      locationId: data['location_id'],
      checkIn: DateTime.parse(data['check_in']),
      metadata: data['metadata'],
    );
  }
}