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
    final pattern = RegExp(r'^[A-Z][0-9]$');
    if (!pattern.hasMatch(scanData)) return null;

    return PaperRollLocationLabel(
      locationId: scanData,
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