import 'package:postgres/postgres.dart';
import '../models/fg_location_label.dart';
import 'label_service.dart';

class FGLocationLabelService extends BaseLabelService<FGLocationLabel> {
  FGLocationLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'fg_location',
        'fg_location_labels'
      );

  @override
  Map<String, dynamic> getLabelValues(FGLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['location_id'];
  }

  @override
  Map<String, dynamic> getSpecificValues(FGLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  FGLocationLabel createLabelFromRow(List<dynamic> row) {
    final checkIn = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final locationId = row[2] as String;

    return FGLocationLabel(
      locationId: locationId,
      checkIn: checkIn,
    );
  }

  Future<List<FGLocationLabel>> searchByArea(String area) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.check_in,
          l.label_type,
          fl.location_id
        FROM labels l
        JOIN fg_location_labels fl ON l.id = fl.label_id
        WHERE l.label_type = @labelType
        AND fl.location_id LIKE @pattern
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'pattern': '$area%',
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching FG location labels by area: $e');
      throw Exception('Failed to search FG location labels: $e');
    }
  }

  Future<List<FGLocationLabel>> getLatestLocations() async {
    try {
      final results = await connection.query(
        '''
        WITH latest_scans AS (
          SELECT location_id, MAX(check_in) as latest_check_in
          FROM fg_location_labels
          GROUP BY location_id
        )
        SELECT 
          l.check_in,
          l.label_type,
          fl.location_id
        FROM labels l
        JOIN fg_location_labels fl ON l.id = fl.label_id
        JOIN latest_scans ls ON fl.location_id = ls.location_id 
          AND fl.check_in = ls.latest_check_in
        WHERE l.label_type = @labelType
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error getting latest FG locations: $e');
      throw Exception('Failed to get latest FG locations: $e');
    }
  }
}