class Location {
  final String locationId;
  final String typeName;

  Location({
    required this.locationId,
    required this.typeName,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationId: json['location_id'],
      typeName: json['type_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'type_name': typeName,
    };
  }
}