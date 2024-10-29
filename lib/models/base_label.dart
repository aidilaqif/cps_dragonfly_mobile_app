class BaseLabel {
  final DateTime checkIn;
  final Map<String, dynamic>? metadata;

  BaseLabel({
    required this.checkIn,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'check_in': checkIn.toIso8601String(),
      'metadata': metadata,
    };
  }
}