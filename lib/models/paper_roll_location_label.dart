import 'package:cps_dragonfly_4_mobile_app/models/base_label.dart';

class PaperRollLocationLabel extends BaseLabel {
  final String locationId;

  PaperRollLocationLabel({
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

  // Get row letter (first character)
  String get rowNumber => locationId.isNotEmpty ? locationId[0] : '';

  // Get position number (second character)
  String get positionNumber =>
      locationId.length > 1 ? locationId.substring(1) : '';

  static PaperRollLocationLabel? fromScanData(String scanData) {
    final cleanValue = scanData.trim().toUpperCase();

    // Format: Letter followed by single digit (S3)
    final pattern = RegExp(r'^[A-Z]\d$');

    if (!pattern.hasMatch(cleanValue)) {
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
