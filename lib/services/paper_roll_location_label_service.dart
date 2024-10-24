import 'package:postgres/postgres.dart';
import '../models/paper_roll_location_label.dart';

class PaperRollLocationLabelService {
  final PostgreSQLConnection connection;

  PaperRollLocationLabelService(this.connection);

  Future<void> insertLabel(PaperRollLocationLabel label, int sessionId) async {
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
            'labelType': 'paper_roll_location',
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
          INSERT INTO paper_roll_location_labels (label_id, location_id)
          VALUES (@labelId, @locationId)
          ''',
          substitutionValues: {
            'labelId': labelId,
            'locationId': label.locationId,
          }
        );
      });
    } catch (e) {
      print('Error inserting paper roll location label: $e');
      throw Exception('Failed to insert paper roll location label: $e');
    }
  }

  Future<List<PaperRollLocationLabel>> fetchLabels() async {
    try {
      final results = await connection.query('''
        SELECT l.scan_time, prl.location_id
        FROM labels l
        JOIN paper_roll_location_labels prl ON l.id = prl.label_id
        WHERE l.label_type = 'paper_roll_location'
        ORDER BY l.scan_time DESC
      ''');

      return results.map((row) => PaperRollLocationLabel(
        timeLog: row[0] is String 
          ? DateTime.parse(row[0] as String)
          : (row[0] as DateTime).toLocal(),
        locationId: row[1] as String,
      )).toList();
    } catch (e) {
      print('Error fetching paper roll location labels: $e');
      throw Exception('Failed to fetch paper roll location labels: $e');
    }
  }
}