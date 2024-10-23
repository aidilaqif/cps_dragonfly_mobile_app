import 'package:postgres/postgres.dart';
import '../models/roll_label.dart';

class RollLabelService {
  final PostgreSQLConnection connection;

  RollLabelService(this.connection);

  Future<void> insertLabel(RollLabel label, int sessionId) async {
    try {
      await connection.transaction((ctx) async {
        final labelResult = await ctx.query(
          '''
          INSERT INTO labels (session_id, label_type, scan_time, is_rescan)
          VALUES (@sessionId, @labelType, @scanTime, @isRescan)
          RETURNING id
          ''',
          substitutionValues: {
            'sessionId': sessionId,
            'labelType': 'roll',
            'scanTime': label.timeLog.toUtc(),
            'isRescan': false,
          }
        );

        if (labelResult.isEmpty) {
          throw Exception('Failed to insert label record');
        }

        final labelId = labelResult.first[0] as int;

        await ctx.query(
          '''
          INSERT INTO roll_labels (label_id, roll_id)
          VALUES (@labelId, @rollId)
          ''',
          substitutionValues: {
            'labelId': labelId,
            'rollId': label.rollId,
          }
        );
      });
    } catch (e) {
      print('Error inserting roll label: $e');
      throw Exception('Failed to insert roll label: $e');
    }
  }

  Future<List<RollLabel>> fetchLabels() async {
    try {
      final results = await connection.query('''
        SELECT l.scan_time, rl.roll_id
        FROM labels l
        JOIN roll_labels rl ON l.id = rl.label_id
        WHERE l.label_type = 'roll'
        ORDER BY l.scan_time DESC
      ''');

      return results.map((row) => RollLabel(
        timeLog: row[0] is String 
          ? DateTime.parse(row[0] as String)
          : (row[0] as DateTime).toLocal(),
        rollId: row[1] as String,
      )).toList();
    } catch (e) {
      print('Error fetching roll labels: $e');
      throw Exception('Failed to fetch roll labels: $e');
    }
  }
}