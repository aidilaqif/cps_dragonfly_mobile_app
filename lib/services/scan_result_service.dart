import 'package:postgres/postgres.dart';
import '../models/scan_result.dart';

class ScanResultService {
  final PostgreSQLConnection connection;

  ScanResultService(this.connection);

  Future<void> insertResult(ScanResult result) async {
    try {
      await connection.query(
        '''
        INSERT INTO scan_results (value, type, timelog)
        VALUES (@value, @type, @timelog)
        ''',
        substitutionValues: {
          'value': result.value,
          'type': result.type,
          'timelog': result.timelog.toIso8601String(),
        },
      );
    } catch (e) {
      print('Error inserting scan result: $e');
      throw Exception('Failed to insert scan result: $e');
    }
  }

  Future<List<ScanResult>> fetchResults({DateTime? fromDate, DateTime? toDate}) async {
    try {
      String query = 'SELECT * FROM scan_results';
      Map<String, dynamic> substitutionValues = {};

      if (fromDate != null || toDate != null) {
        query += ' WHERE';
        if (fromDate != null) {
          query += ' timelog >= @fromDate';
          substitutionValues['fromDate'] = fromDate.toIso8601String();
        }
        if (toDate != null) {
          if (fromDate != null) query += ' AND';
          query += ' timelog <= @toDate';
          substitutionValues['toDate'] = toDate.toIso8601String();
        }
      }

      query += ' ORDER BY timelog DESC';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return results.map((row) => ScanResult.fromMap(row.toColumnMap())).toList();
    } catch (e) {
      print('Error fetching scan results: $e');
      throw Exception('Failed to fetch scan results: $e');
    }
  }

  Future<void> deleteOldResults(DateTime beforeDate) async {
    try {
      await connection.query(
        'DELETE FROM scan_results WHERE timelog < @beforeDate',
        substitutionValues: {
          'beforeDate': beforeDate.toIso8601String(),
        },
      );
    } catch (e) {
      print('Error deleting old scan results: $e');
      throw Exception('Failed to delete old scan results: $e');
    }
  }
}