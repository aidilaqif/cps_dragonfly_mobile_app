import 'package:postgres/postgres.dart';
import '../models/roll_label.dart';
import 'label_service.dart';

class RollLabelService extends BaseLabelService<RollLabel> {
  RollLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'roll',  // labelType
        'roll_labels'  // tableName
      );

  @override
  Map<String, dynamic> getLabelValues(RollLabel label) {
    return {
      'roll_id': label.rollId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['roll_id', 'batch_number', 'sequence_number'];
  }

  @override
  Map<String, dynamic> getSpecificValues(RollLabel label) {
    // Extract batch and sequence numbers from roll ID
    // Example roll ID format: "24A12345" where "24" is batch and "12345" is sequence
    return {
      'roll_id': label.rollId,
      'batch_number': label.rollId.substring(0, 2),
      'sequence_number': label.rollId.substring(3),
    };
  }

  @override
  RollLabel createLabelFromRow(List<dynamic> row) {
    final scanTime = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final isRescan = row[1] as bool;
    final sessionId = row[2] as int;
    final metadata = row[3] as Map<String, dynamic>?;
    final rollId = row[4] as String;

    return RollLabel(
      rollId: rollId,
      timeLog: scanTime,
      isRescan: isRescan,
      sessionId: sessionId.toString(),
      metadata: metadata,
    );
  }

  // Additional methods specific to Roll Labels

  Future<List<RollLabel>> searchByBatchNumber(String batchNumber) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          rl.roll_id,
          rl.batch_number,
          rl.sequence_number
        FROM labels l
        JOIN roll_labels rl ON l.id = rl.label_id
        WHERE l.label_type = @labelType
        AND rl.batch_number = @batchNumber
        ORDER BY l.scan_time DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'batchNumber': batchNumber,
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching roll labels by batch number: $e');
      throw Exception('Failed to search roll labels: $e');
    }
  }

  Future<List<RollLabel>> searchBySequenceRange(
    String startSequence,
    String endSequence,
  ) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          rl.roll_id,
          rl.batch_number,
          rl.sequence_number
        FROM labels l
        JOIN roll_labels rl ON l.id = rl.label_id
        WHERE l.label_type = @labelType
        AND rl.sequence_number BETWEEN @startSequence AND @endSequence
        ORDER BY rl.sequence_number ASC, l.scan_time DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'startSequence': startSequence,
          'endSequence': endSequence,
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching roll labels by sequence range: $e');
      throw Exception('Failed to search roll labels: $e');
    }
  }

  Future<Map<String, dynamic>> getBatchStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH batch_stats AS (
          SELECT 
            rl.batch_number,
            COUNT(*) as total_rolls,
            COUNT(*) FILTER (WHERE l.is_rescan) as rescan_count,
            MIN(rl.sequence_number) as min_sequence,
            MAX(rl.sequence_number) as max_sequence,
            COUNT(DISTINCT l.session_id) as unique_sessions
          FROM labels l
          JOIN roll_labels rl ON l.id = rl.label_id
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
          GROUP BY rl.batch_number
        )
        SELECT 
          COUNT(DISTINCT batch_number) as unique_batches,
          AVG(total_rolls) as avg_rolls_per_batch,
          AVG(rescan_count::float / NULLIF(total_rolls, 0)) * 100 as avg_rescan_percentage,
          SUM(total_rolls) as total_rolls_scanned,
          SUM(rescan_count) as total_rescans,
          AVG(unique_sessions) as avg_sessions_per_batch
        FROM batch_stats
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      if (results.isEmpty) return {};

      return {
        'unique_batches': results.first[0],
        'avg_rolls_per_batch': results.first[1],
        'avg_rescan_percentage': results.first[2],
        'total_rolls_scanned': results.first[3],
        'total_rescans': results.first[4],
        'avg_sessions_per_batch': results.first[5],
      };
    } catch (e) {
      print('Error getting batch statistics: $e');
      throw Exception('Failed to get batch statistics: $e');
    }
  }

  Future<Map<String, List<String>>> getMissingSequences({
    String? batchNumber,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH sequence_ranges AS (
          SELECT 
            batch_number,
            MIN(sequence_number::integer) as min_seq,
            MAX(sequence_number::integer) as max_seq
          FROM roll_labels
          WHERE 1=1
      ''';

      Map<String, dynamic> substitutionValues = {};

      if (batchNumber != null) {
        query += ' AND batch_number = @batchNumber';
        substitutionValues['batchNumber'] = batchNumber;
      }

      query += '''
          GROUP BY batch_number
        ),
        expected_sequences AS (
          SELECT 
            batch_number,
            generate_series(min_seq, max_seq) as expected_seq
          FROM sequence_ranges
        ),
        actual_sequences AS (
          SELECT DISTINCT
            rl.batch_number,
            rl.sequence_number::integer as actual_seq
          FROM roll_labels rl
          JOIN labels l ON rl.label_id = l.id
          WHERE 1=1
      ''';

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
          e.batch_number,
          array_agg(e.expected_seq::text) as missing_sequences
        FROM expected_sequences e
        LEFT JOIN actual_sequences a 
          ON e.batch_number = a.batch_number 
          AND e.expected_seq = a.actual_seq
        WHERE a.actual_seq IS NULL
        GROUP BY e.batch_number
      ''';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      Map<String, List<String>> missingSequences = {};
      for (final row in results) {
        final batch = row[0] as String;
        final sequences = (row[1] as List<dynamic>).cast<String>();
        missingSequences[batch] = sequences;
      }

      return missingSequences;
    } catch (e) {
      print('Error finding missing sequences: $e');
      throw Exception('Failed to find missing sequences: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSequentialScans({
    int minimumSequentialScans = 3,
    Duration maximumTimeBetweenScans = const Duration(minutes: 5),
  }) async {
    try {
      final results = await connection.query(
        '''
        WITH sequential_analysis AS (
          SELECT 
            roll_id,
            scan_time,
            batch_number,
            sequence_number::integer as seq_num,
            LAG(sequence_number::integer) OVER (
              PARTITION BY batch_number 
              ORDER BY scan_time
            ) as prev_seq,
            LAG(scan_time) OVER (
              PARTITION BY batch_number 
              ORDER BY scan_time
            ) as prev_scan_time
          FROM roll_labels rl
          JOIN labels l ON rl.label_id = l.id
          WHERE l.label_type = @labelType
          ORDER BY batch_number, scan_time
        ),
        grouped_sequences AS (
          SELECT 
            roll_id,
            scan_time,
            batch_number,
            seq_num,
            CASE 
              WHEN seq_num = prev_seq + 1 
                AND scan_time - prev_scan_time <= @maxInterval::interval
              THEN 0
              ELSE 1
            END as new_group
          FROM sequential_analysis
        )
        SELECT 
          batch_number,
          MIN(scan_time) as start_time,
          MAX(scan_time) as end_time,
          MIN(seq_num) as start_sequence,
          MAX(seq_num) as end_sequence,
          COUNT(*) as sequence_length
        FROM (
          SELECT 
            *,
            SUM(new_group) OVER (
              ORDER BY batch_number, scan_time
            ) as group_id
          FROM grouped_sequences
        ) grouped
        GROUP BY batch_number, group_id
        HAVING COUNT(*) >= @minSequential
        ORDER BY start_time DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'maxInterval': '${maximumTimeBetweenScans.inSeconds} seconds',
          'minSequential': minimumSequentialScans,
        }
      );

      return results.map((row) => {
        'batch_number': row[0],
        'start_time': row[1],
        'end_time': row[2],
        'start_sequence': row[3],
        'end_sequence': row[4],
        'sequence_length': row[5],
      }).toList();
    } catch (e) {
      print('Error analyzing sequential scans: $e');
      throw Exception('Failed to analyze sequential scans: $e');
    }
  }
}