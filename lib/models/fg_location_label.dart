import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class FGLocationLabel extends BaseLabel {
  final String locationId;

  FGLocationLabel({
    required this.locationId,
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

  String get areaType {
    if (locationId.isEmpty) return 'unknown';

    // Single letter (e.g., 'B') indicates main area
    if (locationId.length == 1 && RegExp(r'^[A-Z]$').hasMatch(locationId)) {
      return 'main';
    }

    // Letter followed by two digits (e.g., 'B01') indicates sub area
    if (locationId.length == 3 &&
        RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId)) {
      return 'sub';
    }

    // R followed by letter and digit 1-5 (e.g., 'RA1') indicates restricted area
    if (RegExp(r'^R[A-Z][1-5]$').hasMatch(locationId)) {
      return 'restricted';
    }

    return 'unknown';
  }

  static FGLocationLabel? fromScanData(String scanData) {
    final cleanValue = scanData.trim().toUpperCase();

    final singleLetterPattern = RegExp(r'^[A-Z]$');
    final letterDigitsPattern = RegExp(r'^[A-Z]\d{2}$');
    final restrictedPattern = RegExp(r'^R[A-Z][1-5]$');

    if (!singleLetterPattern.hasMatch(cleanValue) &&
        !letterDigitsPattern.hasMatch(cleanValue) &&
        !restrictedPattern.hasMatch(cleanValue)) {
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
      locationId: data['location_id'] ?? '',
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
}
