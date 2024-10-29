import 'package:postgres/postgres.dart';
import '../models/paper_roll_location_label.dart';
import 'label_service.dart';

class PaperRollLocationLabelService extends BaseLabelService<PaperRollLocationLabel> {
  PaperRollLocationLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'paper_roll_location',
        'paper_roll_location_labels'
      );

  @override
  Map<String, dynamic> getLabelValues(PaperRollLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['location_id'];
  }

  @override
  Map<String, dynamic> getSpecificValues(PaperRollLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  PaperRollLocationLabel createLabelFromRow(List<dynamic> row) {
    final checkIn = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final locationId = row[2] as String;

    return PaperRollLocationLabel(
      locationId: locationId,
      checkIn: checkIn,
    );
  }

  Future<List<PaperRollLocationLabel>> searchByRow(String row) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.check_in,
          l.label_type,
          prl.location_id
        FROM labels l
        JOIN paper_roll_location_labels prl ON l.id = prl.label_id
        WHERE l.label_type = @labelType
        AND prl.location_id LIKE @pattern
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'pattern': '$row%',
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching paper roll location labels by row: $e');
      throw Exception('Failed to search paper roll location labels: $e');
    }
  }

  Future<List<PaperRollLocationLabel>> getLatestLocations() async {
    try {
      final results = await connection.query(
        '''
        WITH latest_scans AS (
          SELECT location_id, MAX(check_in) as latest_check_in
          FROM paper_roll_location_labels
          GROUP BY location_id
        )
        SELECT 
          l.check_in,
          l.label_type,
          prl.location_id
        FROM labels l
        JOIN paper_roll_location_labels prl ON l.id = prl.label_id
        JOIN latest_scans ls ON prl.location_id = ls.location_id 
          AND prl.check_in = ls.latest_check_in
        WHERE l.label_type = @labelType
        ORDER BY prl.location_id, l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error getting latest paper roll locations: $e');
      throw Exception('Failed to get latest paper roll locations: $e');
    }
  }

  Future<Map<String, List<String>>> getLocationMap() async {
    try {
      final results = await connection.query(
        '''
        WITH latest_scans AS (
          SELECT location_id, MAX(check_in) as latest_check_in
          FROM paper_roll_location_labels
          GROUP BY location_id
        )
        SELECT 
          SUBSTRING(prl.location_id, 1, 1) as row_id,
          prl.location_id
        FROM paper_roll_location_labels prl
        JOIN latest_scans ls ON prl.location_id = ls.location_id 
          AND prl.check_in = ls.latest_check_in
        ORDER BY prl.location_id
        '''
      );

      Map<String, List<String>> locationMap = {};
      for (final row in results) {
        final rowId = row[0] as String;
        final locationId = row[1] as String;
        locationMap.putIfAbsent(rowId, () => []).add(locationId);
      }

      return locationMap;
    } catch (e) {
      print('Error getting paper roll location map: $e');
      throw Exception('Failed to get paper roll location map: $e');
    }
  }
}