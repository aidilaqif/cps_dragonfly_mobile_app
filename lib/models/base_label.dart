class BaseLabel {
  final DateTime checkIn;
  final Map<String, dynamic>? metadata;
  final String? status;
  final DateTime? statusUpdatedAt;
  final String? statusNotes;

  BaseLabel({
    required this.checkIn,
    this.metadata,
    this.status,
    this.statusUpdatedAt,
    this.statusNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'check_in': checkIn.toIso8601String(),
      'metadata': metadata,
      'status': status,
      'status_notes': statusNotes,
      'status_updated_at': statusUpdatedAt?.toIso8601String(),
    };
  }
}