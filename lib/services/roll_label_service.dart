import 'package:postgres/postgres.dart';
import '../models/roll_label.dart';
import 'label_service.dart';

class RollLabelService extends BaseLabelService<RollLabel> {
  RollLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'roll',
        'roll_labels'
      );

  @override
  Map<String, dynamic> getLabelValues(RollLabel label) {
    return {
      'roll_id': label.rollId,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['roll_id'];
  }

  @override
  Map<String, dynamic> getSpecificValues(RollLabel label) {
    return {
      'roll_id': label.rollId,
    };
  }

  @override
  RollLabel createLabelFromRow(List<dynamic> row) {
    final checkIn = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final rollId = row[2] as String;

    return RollLabel(
      rollId: rollId,
      checkIn: checkIn,
    );
  }

  Future<List<RollLabel>> searchByBatchNumber(String batchNumber) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.check_in,
          l.label_type,
          rl.roll_id
        FROM labels l
        JOIN roll_labels rl ON l.id = rl.label_id
        WHERE l.label_type = @labelType
        AND rl.roll_id LIKE @pattern
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'pattern': '$batchNumber%',
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching roll labels by batch number: $e');
      throw Exception('Failed to search roll labels: $e');
    }
  }
}