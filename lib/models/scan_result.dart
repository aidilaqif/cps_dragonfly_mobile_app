class ScanResult {
  final String value;
  final String type;
  final DateTime timelog;

  ScanResult({
    required this.value,
    required this.type,
    required this.timelog,
  });

  factory ScanResult.fromMap(Map<String, dynamic> data) {
    return ScanResult(
      value: data['value'],
      type: data['type'],
      timelog: DateTime.parse(data['timelog']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'type': type,
      'timelog': timelog.toIso8601String(),
    };
  }
}
