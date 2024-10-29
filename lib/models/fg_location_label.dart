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
  // Clean the input
  final cleanValue = scanData.trim().toUpperCase();
  print('FG Location validation for: "$cleanValue"');
  
  // Three possible formats:
  // 1. Single letter (B)
  // 2. Letter + two digits (B01)
  // 3. Restricted area (RA1)
  final singleLetterPattern = RegExp(r'^[A-Z]$');
  final letterDigitsPattern = RegExp(r'^[A-Z]\d{2}$');
  final restrictedPattern = RegExp(r'^R[A-Z][1-5]$');
  
  if (!singleLetterPattern.hasMatch(cleanValue) && 
      !letterDigitsPattern.hasMatch(cleanValue) &&
      !restrictedPattern.hasMatch(cleanValue)) {
    print('FG Location failed validation. Must be either:');
    print('- Single letter (e.g., B)');
    print('- Letter followed by 2 digits (e.g., B01)');
    print('- R followed by letter and digit 1-5 (e.g., RA1)');
    return null;
  }

  return FGLocationLabel(
    locationId: cleanValue,
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