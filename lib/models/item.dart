class Item {
  final String labelId;
  final String labelType;
  final String location;
  final String status;
  final String lastScanTime;

  Item({
    required this.labelId,
    required this.labelType,
    required this.location,
    required this.status,
    required this.lastScanTime,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      labelId: json['label_id'] ?? json['labelId'] ?? '',
      labelType: json['label_type'] ?? json['labelType'] ?? '',
      location: json['location_id'] ?? json['location'] ?? '',
      status: json['status'] ?? 'Unresolved',
      lastScanTime: json['last_scan_time'] ??
          json['lastScanTime'] ??
          DateTime.now().toIso8601String(),
    );
  }
}
