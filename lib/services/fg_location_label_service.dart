import 'package:postgres/postgres.dart';
import '../models/fg_location_label.dart';
import 'label_service.dart';

class FGLocationLabelService extends BaseLabelService<FGLocationLabel> {
  FGLocationLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'fg_location',  // labelType
        'fg_location_labels'  // tableName
      );

  @override
  Map<String, dynamic> getLabelValues(FGLocationLabel label) {
    return {
      'location_id': label.locationId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['location_id', 'area_type'];
  }

  @override
  Map<String, dynamic> getSpecificValues(FGLocationLabel label) {
    // Determine area type based on location ID format
    String areaType = _determineAreaType(label.locationId);
    
    return {
      'location_id': label.locationId,
      'area_type': areaType,
    };
  }

  String _determineAreaType(String locationId) {
    // Single letter (like B) -> main area
    // Letter followed by 2 digits (like B01) -> sub area
    // R followed by letter and digit 1-5 (like RA1) -> restricted area
    if (locationId.length == 1) {
      return 'main';
    } else if (locationId.length == 3 && RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId)) {
      return 'sub';
    } else if (RegExp(r'^R[A-Z][1-5]$').hasMatch(locationId)) {
      return 'restricted';
    }
    return 'unknown';
  }

  @override
  FGLocationLabel createLabelFromRow(List<dynamic> row) {
    final scanTime = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final isRescan = row[1] as bool;
    final sessionId = row[2] as int;
    final metadata = row[3] as Map<String, dynamic>?;
    final locationId = row[4] as String;
    final areaType = row[5] as String;

    return FGLocationLabel(
      locationId: locationId,
      timeLog: scanTime,
      isRescan: isRescan,
      sessionId: sessionId.toString(),
      metadata: {
        ...?metadata,
        'area_type': areaType,
      },
    );
  }

  // Additional methods specific to FG Location Labels

  Future<List<FGLocationLabel>> searchByArea(String area) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          fl.location_id,
          fl.area_type
        FROM labels l
        JOIN fg_location_labels fl ON l.id = fl.label_id
        WHERE l.label_type = @labelType
        AND (
          fl.location_id LIKE @areaPattern
          OR fl.area_type = @area
        )
        ORDER BY l.scan_time DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'areaPattern': '$area%',
          'area': area.toLowerCase(),
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching FG location labels by area: $e');
      throw Exception('Failed to search FG location labels: $e');
    }
  }

  Future<Map<String, dynamic>> getLocationStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH location_stats AS (
          SELECT 
            fl.area_type,
            COUNT(*) as total_scans,
            COUNT(*) FILTER (WHERE l.is_rescan) as rescan_count,
            COUNT(DISTINCT fl.location_id) as unique_locations,
            COUNT(DISTINCT l.session_id) as unique_sessions,
            AVG(EXTRACT(EPOCH FROM (
              l.scan_time - LAG(l.scan_time) OVER (
                PARTITION BY fl.location_id 
                ORDER BY l.scan_time
              )
            ))) FILTER (WHERE l.is_rescan) as avg_rescan_interval
          FROM labels l
          JOIN fg_location_labels fl ON l.id = fl.label_id
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
          GROUP BY fl.area_type
        )
        SELECT 
          area_type,
          total_scans,
          rescan_count,
          unique_locations,
          unique_sessions,
          avg_rescan_interval
        FROM location_stats
        ORDER BY total_scans DESC
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, dynamic> statistics = {
        'by_area_type': {},
        'overall': {
          'total_scans': 0,
          'rescan_count': 0,
          'unique_locations': 0,
          'unique_sessions': 0,
        }
      };

      for (final row in results) {
        final areaType = row[0] as String;
        statistics['by_area_type'][areaType] = {
          'total_scans': row[1],
          'rescan_count': row[2],
          'unique_locations': row[3],
          'unique_sessions': row[4],
          'avg_rescan_interval_seconds': row[5],
        };

        // Update overall totals
        statistics['overall']['total_scans'] += row[1] as int;
        statistics['overall']['rescan_count'] += row[2] as int;
        statistics['overall']['unique_locations'] += row[3] as int;
        if (row[4] as int > statistics['overall']['unique_sessions']) {
          statistics['overall']['unique_sessions'] = row[4] as int;
        }
      }

      return statistics;
    } catch (e) {
      print('Error getting location statistics: $e');
      throw Exception('Failed to get location statistics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHighTrafficLocations({
    DateTime? startDate,
    DateTime? endDate,
    int minimumScans = 10,
  }) async {
    try {
      String query = '''
        WITH scan_patterns AS (
          SELECT 
            fl.location_id,
            fl.area_type,
            COUNT(*) as total_scans,
            COUNT(*) FILTER (WHERE l.is_rescan) as rescan_count,
            MIN(l.scan_time) as first_scan,
            MAX(l.scan_time) as last_scan,
            COUNT(DISTINCT l.session_id) as unique_sessions,
            AVG(EXTRACT(EPOCH FROM (
              l.scan_time - LAG(l.scan_time) OVER (
                PARTITION BY fl.location_id 
                ORDER BY l.scan_time
              )
            ))) as avg_interval_seconds
          FROM labels l
          JOIN fg_location_labels fl ON l.id = fl.label_id
          WHERE l.label_type = @labelType
      ''';

      Map<String, dynamic> substitutionValues = {
        'labelType': labelType,
        'minScans': minimumScans,
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
          GROUP BY fl.location_id, fl.area_type
          HAVING COUNT(*) >= @minScans
        )
        SELECT 
          location_id,
          area_type,
          total_scans,
          rescan_count,
          first_scan,
          last_scan,
          unique_sessions,
          avg_interval_seconds
        FROM scan_patterns
        ORDER BY total_scans DESC
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return results.map((row) => {
        'location_id': row[0],
        'area_type': row[1],
        'total_scans': row[2],
        'rescan_count': row[3],
        'first_scan': row[4],
        'last_scan': row[5],
        'unique_sessions': row[6],
        'avg_interval_seconds': row[7],
      }).toList();
    } catch (e) {
      print('Error analyzing high traffic locations: $e');
      throw Exception('Failed to analyze high traffic locations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnusualScanPatterns({
    Duration threshold = const Duration(minutes: 30),
    int minimumSequentialScans = 3,
  }) async {
    try {
      final results = await connection.query(
        '''
        WITH sequential_scans AS (
          SELECT 
            fl.location_id,
            fl.area_type,
            l.scan_time,
            l.session_id,
            l.is_rescan,
            EXTRACT(EPOCH FROM (
              l.scan_time - LAG(l.scan_time) OVER (
                PARTITION BY fl.location_id 
                ORDER BY l.scan_time
              )
            )) as interval_seconds
          FROM labels l
          JOIN fg_location_labels fl ON l.id = fl.label_id
          WHERE l.label_type = @labelType
          ORDER BY fl.location_id, l.scan_time
        )
        SELECT 
          location_id,
          area_type,
          MIN(scan_time) as pattern_start,
          MAX(scan_time) as pattern_end,
          COUNT(*) as scan_count,
          AVG(interval_seconds) as avg_interval,
          COUNT(DISTINCT session_id) as session_count,
          SUM(CASE WHEN is_rescan THEN 1 ELSE 0 END) as rescan_count
        FROM sequential_scans
        WHERE interval_seconds <= @thresholdSeconds
        GROUP BY location_id, area_type
        HAVING COUNT(*) >= @minSequential
        ORDER BY scan_count DESC, avg_interval
        ''',
        substitutionValues: {
          'labelType': labelType,
          'thresholdSeconds': threshold.inSeconds,
          'minSequential': minimumSequentialScans,
        }
      );

      return results.map((row) => {
        'location_id': row[0],
        'area_type': row[1],
        'pattern_start': row[2],
        'pattern_end': row[3],
        'scan_count': row[4],
        'avg_interval_seconds': row[5],
        'session_count': row[6],
        'rescan_count': row[7],
      }).toList();
    } catch (e) {
      print('Error detecting unusual scan patterns: $e');
      throw Exception('Failed to detect unusual scan patterns: $e');
    }
  }
}