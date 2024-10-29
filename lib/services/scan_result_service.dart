import 'package:postgres/postgres.dart';
import '../models/scan_result.dart';

class ScanResultService {
  final PostgreSQLConnection connection;

  ScanResultService(this.connection);

  Future<void> insertResult(ScanResult result) async {
    try {
      await connection.transaction((ctx) async {
        // First check if this value has been scanned before
        final previousScan = await _findPreviousScan(result.value, result.type);
        
        // Determine if this is a rescan
        final isRescan = previousScan != null;
        final originalSessionId = previousScan?['session_id'];
        final firstScanTime = previousScan?['first_scan'];

        // Insert the scan result with rescan information
        await ctx.query(
          '''
          INSERT INTO scan_results (
            value,
            type,
            timelog,
            is_rescan,
            original_session_id,
            first_scan_time,
            metadata
          )
          VALUES (
            @value,
            @type,
            @timelog,
            @isRescan,
            @originalSessionId,
            @firstScanTime,
            @metadata
          )
          ''',
          substitutionValues: {
            'value': result.value,
            'type': result.type,
            'timelog': result.timelog.toUtc(),
            'isRescan': isRescan,
            'originalSessionId': originalSessionId,
            'firstScanTime': firstScanTime ?? result.timelog.toUtc(),
            'metadata': result.metadata,
          },
        );

        // Update scan statistics
        await _updateScanStats(
          ctx,
          result.type,
          isRescan,
          result.timelog.toUtc(),
        );
      });
    } catch (e) {
      print('Error inserting scan result: $e');
      throw Exception('Failed to insert scan result: $e');
    }
  }

  Future<Map<String, dynamic>?> _findPreviousScan(String value, String type) async {
    final result = await connection.query(
      '''
      SELECT 
        session_id,
        MIN(timelog) as first_scan
      FROM scan_results
      WHERE value = @value AND type = @type
      GROUP BY session_id
      ORDER BY first_scan
      LIMIT 1
      ''',
      substitutionValues: {
        'value': value,
        'type': type,
      },
    );

    if (result.isEmpty) return null;

    return {
      'session_id': result.first[0],
      'first_scan': result.first[1],
    };
  }

  Future<void> _updateScanStats(
    PostgreSQLExecutionContext ctx,
    String type,
    bool isRescan,
    DateTime scanTime,
  ) async {
    await ctx.query(
      '''
      INSERT INTO scan_statistics (
        scan_type,
        scan_date,
        total_scans,
        new_scans,
        rescans
      )
      VALUES (
        @type,
        @date,
        1,
        @newScan,
        @rescan
      )
      ON CONFLICT (scan_type, scan_date)
      DO UPDATE SET
        total_scans = scan_statistics.total_scans + 1,
        new_scans = scan_statistics.new_scans + CASE WHEN @isRescan THEN 0 ELSE 1 END,
        rescans = scan_statistics.rescans + CASE WHEN @isRescan THEN 1 ELSE 0 END
      ''',
      substitutionValues: {
        'type': type,
        'date': DateTime.utc(scanTime.year, scanTime.month, scanTime.day),
        'isRescan': isRescan,
        'newScan': isRescan ? 0 : 1,
        'rescan': isRescan ? 1 : 0,
      },
    );
  }

  Future<List<ScanResult>> fetchResults({
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
    bool? isRescan,
    String? sessionId,
  }) async {
    try {
      String query = '''
        SELECT 
          value,
          type,
          timelog,
          is_rescan,
          original_session_id,
          first_scan_time,
          metadata
        FROM scan_results
        WHERE 1=1
      ''';
      
      Map<String, dynamic> substitutionValues = {};

      if (fromDate != null) {
        query += ' AND timelog >= @fromDate';
        substitutionValues['fromDate'] = fromDate.toUtc();
      }
      
      if (toDate != null) {
        query += ' AND timelog <= @toDate';
        substitutionValues['toDate'] = toDate.toUtc();
      }
      
      if (type != null) {
        query += ' AND type = @type';
        substitutionValues['type'] = type;
      }
      
      if (isRescan != null) {
        query += ' AND is_rescan = @isRescan';
        substitutionValues['isRescan'] = isRescan;
      }
      
      if (sessionId != null) {
        query += ' AND (session_id = @sessionId OR original_session_id = @sessionId)';
        substitutionValues['sessionId'] = sessionId;
      }

      query += ' ORDER BY timelog DESC';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return results.map((row) => ScanResult.fromMap({
        'value': row[0],
        'type': row[1],
        'timelog': row[2],
        'is_rescan': row[3],
        'original_session_id': row[4],
        'first_scan_time': row[5],
        'metadata': row[6],
      })).toList();
    } catch (e) {
      print('Error fetching scan results: $e');
      throw Exception('Failed to fetch scan results: $e');
    }
  }

  Future<Map<String, Map<String, int>>> fetchScanStatistics({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? types,
  }) async {
    try {
      String query = '''
        SELECT 
          scan_type,
          scan_date,
          total_scans,
          new_scans,
          rescans
        FROM scan_statistics
        WHERE 1=1
      ''';
      
      Map<String, dynamic> substitutionValues = {};

      if (fromDate != null) {
        query += ' AND scan_date >= @fromDate';
        substitutionValues['fromDate'] = fromDate;
      }
      
      if (toDate != null) {
        query += ' AND scan_date <= @toDate';
        substitutionValues['toDate'] = toDate;
      }
      
      if (types != null && types.isNotEmpty) {
        query += ' AND scan_type = ANY(@types)';
        substitutionValues['types'] = types;
      }

      query += ' ORDER BY scan_date';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, Map<String, int>> statistics = {};
      
      for (final row in results) {
        final type = row[0] as String;
        final total = row[2] as int;
        final newScans = row[3] as int;
        final rescans = row[4] as int;

        statistics[type] = {
          'total': total,
          'new': newScans,
          'rescans': rescans,
        };
      }

      return statistics;
    } catch (e) {
      print('Error fetching scan statistics: $e');
      throw Exception('Failed to fetch scan statistics: $e');
    }
  }

  Future<void> deleteOldResults(DateTime beforeDate) async {
    try {
      await connection.transaction((ctx) async {
        // Delete old scan results
        await ctx.query(
          'DELETE FROM scan_results WHERE timelog < @beforeDate',
          substitutionValues: {
            'beforeDate': beforeDate.toUtc(),
          },
        );

        // Clean up statistics for deleted dates
        await ctx.query(
          'DELETE FROM scan_statistics WHERE scan_date < @beforeDate',
          substitutionValues: {
            'beforeDate': beforeDate,
          },
        );
      });
    } catch (e) {
      print('Error deleting old scan results: $e');
      throw Exception('Failed to delete old scan results: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRescanAnalysis({
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) async {
    try {
      String query = '''
        WITH rescan_intervals AS (
          SELECT 
            value,
            type,
            timelog,
            LAG(timelog) OVER (PARTITION BY value, type ORDER BY timelog) as previous_scan,
            is_rescan
          FROM scan_results
          WHERE is_rescan = true
      ''';
      
      Map<String, dynamic> substitutionValues = {};

      if (fromDate != null) {
        query += ' AND timelog >= @fromDate';
        substitutionValues['fromDate'] = fromDate.toUtc();
      }
      
      if (toDate != null) {
        query += ' AND timelog <= @toDate';
        substitutionValues['toDate'] = toDate.toUtc();
      }
      
      if (type != null) {
        query += ' AND type = @type';
        substitutionValues['type'] = type;
      }

      query += '''
        )
        SELECT 
          type,
          COUNT(*) as rescan_count,
          AVG(EXTRACT(EPOCH FROM (timelog - previous_scan))) as avg_rescan_interval,
          MIN(EXTRACT(EPOCH FROM (timelog - previous_scan))) as min_rescan_interval,
          MAX(EXTRACT(EPOCH FROM (timelog - previous_scan))) as max_rescan_interval
        FROM rescan_intervals
        WHERE previous_scan IS NOT NULL
        GROUP BY type
        ORDER BY type
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return results.map((row) => {
        'type': row[0],
        'rescan_count': row[1],
        'avg_interval_seconds': row[2],
        'min_interval_seconds': row[3],
        'max_interval_seconds': row[4],
      }).toList();
    } catch (e) {
      print('Error analyzing rescans: $e');
      throw Exception('Failed to analyze rescans: $e');
    }
  }
}