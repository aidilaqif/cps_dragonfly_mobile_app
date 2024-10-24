import 'package:postgres/postgres.dart';
import '../models/fg_pallet_label.dart';

class FGPalletLabelService {
  final PostgreSQLConnection connection;

  FGPalletLabelService(this.connection);

  Future<void> insertLabel(FGPalletLabel label, int sessionId) async {
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
            'labelType': 'fg_pallet',
            'scanTime': label.timeLog.toUtc(), // Convert to UTC for storage
            'isRescan': false,
          }
        );
        
        if (labelResult.isEmpty) {
          throw Exception('Failed to insert label record');
        }
        
        final labelId = labelResult.first[0] as int;
        
        await ctx.query(
          '''
          INSERT INTO fg_pallet_labels (label_id, plate_id, work_order)
          VALUES (@labelId, @plateId, @workOrder)
          ''',
          substitutionValues: {
            'labelId': labelId,
            'plateId': label.plateId,
            'workOrder': label.workOrder,
          }
        );
      });
    } catch (e) {
      print('Error inserting FG pallet label: $e');
      throw Exception('Failed to insert FG pallet label: $e');
    }
  }

  Future<List<FGPalletLabel>> fetchLabels() async {
    try {
      final results = await connection.query('''
        SELECT l.scan_time, fpl.plate_id, fpl.work_order
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        WHERE l.label_type = 'fg_pallet'
        ORDER BY l.scan_time DESC
      ''');
      
      return results.map((row) => FGPalletLabel(
        timeLog: row[0] is String 
          ? DateTime.parse(row[0] as String)
          : (row[0] as DateTime).toLocal(), // Handle both String and DateTime
        plateId: row[1] as String,
        workOrder: row[2] as String,
        rawValue: '${row[1]}-${row[2]}',
      )).toList();
    } catch (e) {
      print('Error fetching FG pallet labels: $e');
      throw Exception('Failed to fetch FG pallet labels: $e');
    }
  }
}