import 'package:cps_dragonfly_4_mobile_app/services/label_service.dart';
import 'package:postgres/postgres.dart';
import '../models/paper_roll_location_label.dart';

class PaperRollLocationLabelService extends BaseLabelService<PaperRollLocationLabel> {
  PaperRollLocationLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'paper_roll_location',  // labelType
        'paper_roll_location_labels'  // tableName
      );

  @override
  Map<String, dynamic> getLabelValues(PaperRollLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['location_id', 'row_number', 'position_number'];
  }

  @override
  Map<String, dynamic> getSpecificValues(PaperRollLocationLabel label) {
    // Parse location ID format (e.g., "A1" where "A" is row and "1" is position)
    return {
      'location_id': label.locationId,
      'row_number': label.locationId[0],
      'position_number': label.locationId[1],
    };
  }

  @override
  PaperRollLocationLabel createLabelFromRow(List<dynamic> row) {
    final scanTime = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final isRescan = row[1] as bool;
    final sessionId = row[2] as int;
    final metadata = row[3] as Map<String, dynamic>?;
    final locationId = row[4] as String;

    return PaperRollLocationLabel(
      locationId: locationId,
      timeLog: scanTime,
      isRescan: isRescan,
      sessionId: sessionId.toString(),
      metadata: metadata,
    );
  }

  // Additional methods specific to Paper Roll Location Labels

  Future<List<PaperRollLocationLabel>> searchByRow(String row) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          prl.location_id,
          prl.row_number,
          prl.position_number
        FROM labels l
        JOIN paper_roll_location_labels prl ON l.id = prl.label_id
        WHERE l.label_type = @labelType
        AND prl.row_number = @row
        ORDER BY prl.position_number ASC, l.scan_time DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'row': row,
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching paper roll locations by row: $e');
      throw Exception('Failed to search paper roll locations: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> getRowUtilization({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH position_stats AS (
          SELECT 
            prl.row_number,
            prl.position_number,
            COUNT(*) as scan_count,
            COUNT(*) FILTER (WHERE l.is_rescan) as rescan_count,
            COUNT(DISTINCT l.session_id) as unique_sessions,
            MIN(l.scan_time) as first_scan,
            MAX(l.scan_time) as last_scan
          FROM labels l
          JOIN paper_roll_location_labels prl ON l.id = prl.label_id
          WHERE l.label_type = @labelType
      ''';

      Map<String, dynamic> substitutionValues = {
        'labelType': labelType,
      };

      if (startDate != null) {
        query += ' AND l.scan_time >= @startDate';
        substitutionValues['startDate'] = startDate.toUtc();
      }

      if (endDate != null) {
        query += ' AND l.scan_time <= @endDate';
        substitutionValues['endDate'] = endDate.toUtc();
      }

      query += '''
          GROUP BY prl.row_number, prl.position_number
        )
        SELECT 
          row_number,
          COUNT(*) as total_positions,
          SUM(scan_count) as total_scans,
          AVG(scan_count) as avg_scans_per_position,
          SUM(rescan_count) as total_rescans,
          COUNT(DISTINCT position_number) as used_positions,
          MIN(first_scan) as row_first_use,
          MAX(last_scan) as row_last_use,
          AVG(unique_sessions) as avg_sessions_per_position
        FROM position_stats
        GROUP BY row_number
        ORDER BY row_number
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, Map<String, dynamic>> utilization = {};
      
      for (final row in results) {
        utilization[row[0] as String] = {
          'total_positions': row[1],
          'total_scans': row[2],
          'avg_scans_per_position': row[3],
          'total_rescans': row[4],
          'used_positions': row[5],
          'utilization_percentage': (row[5] / row[1] * 100).toStringAsFixed(1),
          'first_use': row[6],
          'last_use': row[7],
          'avg_sessions_per_position': row[8],
        };
      }

      return utilization;
    } catch (e) {
      print('Error getting row utilization: $e');
      throw Exception('Failed to get row utilization: $e');
    }
  }

  Future<List<Map<String, dynamic>>> findUnusedPositions() async {
    try {
      final results = await connection.query(
        '''
        WITH all_positions AS (
          SELECT 
            r.row_letter,
            p.position_number,
            r.row_letter || p.position_number as location_id
          FROM (
            SELECT DISTINCT UNNEST(STRING_TO_ARRAY('ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL)) as row_letter
          ) r
          CROSS JOIN (
            SELECT generate_series(1, 9)::text as position_number
          ) p
        ),
        used_positions AS (
          SELECT DISTINCT location_id
          FROM paper_roll_location_labels
        )
        SELECT 
          ap.row_letter as row,
          ap.position_number as position,
          ap.location_id,
          CASE 
            WHEN up.location_id IS NULL THEN 'never_used'
            ELSE 'used'
          END as status
        FROM all_positions ap
        LEFT JOIN used_positions up ON ap.location_id = up.location_id
        ORDER BY ap.row_letter, ap.position_number::int
        '''
      );

      return results.map((row) => {
        'row': row[0],
        'position': row[1],
        'location_id': row[2],
        'status': row[3],
      }).toList();
    } catch (e) {
      print('Error finding unused positions: $e');
      throw Exception('Failed to find unused positions: $e');
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> getPositionTransitions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH transitions AS (
          SELECT 
            prl.location_id,
            prl.row_number,
            prl.position_number,
            l.scan_time,
            l.session_id,
            LAG(l.scan_time) OVER (
              PARTITION BY prl.location_id 
              ORDER BY l.scan_time
            ) as previous_scan,
            LAG(l.session_id) OVER (
              PARTITION BY prl.location_id 
              ORDER BY l.scan_time
            ) as previous_session
          FROM labels l
          JOIN paper_roll_location_labels prl ON l.id = prl.label_id
          WHERE l.label_type = @labelType
      ''';

      Map<String, dynamic> substitutionValues = {
        'labelType': labelType,
      };

      if (startDate != null) {
        query += ' AND l.scan_time >= @startDate';
        substitutionValues['startDate'] = startDate.toUtc();
      }

      if (endDate != null) {
        query += ' AND l.scan_time <= @endDate';
        substitutionValues['endDate'] = endDate.toUtc();
      }

      query += '''
        )
        SELECT 
          row_number,
          position_number,
          location_id,
          scan_time,
          previous_scan,
          EXTRACT(EPOCH FROM (scan_time - previous_scan)) as interval_seconds,
          session_id != previous_session as is_new_session
        FROM transitions
        WHERE previous_scan IS NOT NULL
        ORDER BY row_number, position_number, scan_time
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, List<Map<String, dynamic>>> transitions = {};

      for (final row in results) {
        final rowNumber = row[0] as String;
        transitions.putIfAbsent(rowNumber, () => []).add({
          'position': row[1],
          'location_id': row[2],
          'scan_time': row[3],
          'previous_scan': row[4],
          'interval_seconds': row[5],
          'is_new_session': row[6],
        });
      }

      return transitions;
    } catch (e) {
      print('Error analyzing position transitions: $e');
      throw Exception('Failed to analyze position transitions: $e');
    }
  }

  Future<Map<String, dynamic>> getLocationAccessPatterns({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH hourly_patterns AS (
          SELECT 
            prl.row_number,
            EXTRACT(HOUR FROM l.scan_time) as hour_of_day,
            COUNT(*) as scan_count
          FROM labels l
          JOIN paper_roll_location_labels prl ON l.id = prl.label_id
          WHERE l.label_type = @labelType
      ''';

      Map<String, dynamic> substitutionValues = {
        'labelType': labelType,
      };

      if (startDate != null) {
        query += ' AND l.scan_time >= @startDate';
        substitutionValues['startDate'] = startDate.toUtc();
      }

      if (endDate != null) {
        query += ' AND l.scan_time <= @endDate';
        substitutionValues['endDate'] = endDate.toUtc();
      }

      query += '''
          GROUP BY prl.row_number, EXTRACT(HOUR FROM l.scan_time)
        ),
        row_patterns AS (
          SELECT 
            row_number,
            json_object_agg(
              hour_of_day::text, 
              scan_count
            ) as hourly_distribution
          FROM hourly_patterns
          GROUP BY row_number
        )
        SELECT 
          row_number,
          hourly_distribution,
          (
            SELECT json_object_agg(
              position_number,
              scan_count
            )
            FROM (
              SELECT 
                position_number,
                COUNT(*) as scan_count
              FROM paper_roll_location_labels prl2
              JOIN labels l2 ON prl2.label_id = l2.id
              WHERE prl2.row_number = rp.row_number
              GROUP BY position_number
            ) pos_stats
          ) as position_distribution
        FROM row_patterns rp
        ORDER BY row_number
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, dynamic> patterns = {};

      for (final row in results) {
        patterns[row[0] as String] = {
          'hourly_distribution': row[1],
          'position_distribution': row[2],
        };
      }

      return patterns;
    } catch (e) {
      print('Error analyzing location access patterns: $e');
      throw Exception('Failed to analyze location access patterns: $e');
    }
  }
}