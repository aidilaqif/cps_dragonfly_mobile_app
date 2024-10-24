import 'package:postgres/postgres.dart';
import '../models/fg_location_label.dart';

class FGLocationLabelService {
  final PostgreSQLConnection connection;

  FGLocationLabelService(this.connection);

  Future<void> insertLabel(FGLocationLabel label, int sessionId) async {
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
            'labelType': 'fg_location',
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
          INSERT INTO fg_location_labels (label_id, location_id)
          VALUES (@labelId, @locationId)
          ''',
          substitutionValues: {
            'labelId': labelId,
            'locationId': label.locationId,
          }
        );
      });
    } catch (e) {
      print('Error inserting FG location label: $e');
      throw Exception('Failed to insert FG location label: $e');
    }
  }

  Future<List<FGLocationLabel>> fetchLabels() async {
    try {
      final results = await connection.query('''
        SELECT l.scan_time, fl.location_id
        FROM labels l
        JOIN fg_location_labels fl ON l.id = fl.label_id
        WHERE l.label_type = 'fg_location'
        ORDER BY l.scan_time DESC
      ''');

      return results.map((row) => FGLocationLabel(
        timeLog: row[0] is String 
          ? DateTime.parse(row[0] as String)
          : (row[0] as DateTime).toLocal(),
        locationId: row[1] as String,
      )).toList();
    } catch (e) {
      print('Error fetching FG location labels: $e');
      throw Exception('Failed to fetch FG location labels: $e');
    }
  }
}