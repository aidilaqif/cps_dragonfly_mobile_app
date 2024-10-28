import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class FGLocationLabel extends BaseLabel {
  final String locationId;

  FGLocationLabel({
    required this.locationId,
    required DateTime checkIn,
    Map<String, dynamic>? metadata,
  }) : super(
    checkIn: checkIn,
    metadata: metadata,
  );

  String get areaType {
    if (locationId.length == 1) return 'main';
    if (locationId.length == 3 && RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId)) return 'sub';
    if (RegExp(r'^R[A-Z][1-5]$').hasMatch(locationId)) return 'restricted';
    return 'unknown';
  }

  static FGLocationLabel? fromScanData(String scanData) {
    // Pattern matches:
    // - Single letter (like B)
    // - Any letter followed by 2 digits (like B01, A07)
    // - R followed by any letter and a digit 1-5 (like RA1, RB4, RC3)
    final pattern = RegExp(r'^([A-Za-z]|[A-Za-z]\d{2}|R[A-Za-z][1-5])$');
    if (!pattern.hasMatch(scanData)) return null;

    return FGLocationLabel(
      locationId: scanData.toUpperCase(),
      checkIn: DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'location_id': locationId,
      'area_type': areaType,
    };
  }

  factory FGLocationLabel.fromMap(Map<String, dynamic> data) {
    return FGLocationLabel(
      locationId: data['location_id'],
      checkIn: DateTime.parse(data['check_in']),
      metadata: data['metadata'],
    );
  }
}