import 'package:postgres/postgres.dart';
import '../models/fg_pallet_label.dart';
import 'label_service.dart';

class FGPalletLabelService extends BaseLabelService<FGPalletLabel> {
  FGPalletLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'fg_pallet',
        'fg_pallet_labels'
      );

  @override
  Map<String, dynamic> getLabelValues(FGPalletLabel label) {
    return {
      'raw_value': label.rawValue,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['raw_value', 'plate_id', 'work_order'];
  }

  @override
  Map<String, dynamic> getSpecificValues(FGPalletLabel label) {
    return {
      'raw_value': label.rawValue,
      'plate_id': label.plateId,
      'work_order': label.workOrder,
    };
  }

  @override
  FGPalletLabel createLabelFromRow(List<dynamic> row) {
    final checkIn = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final rawValue = row[2] as String;
    final plateId = row[3] as String;
    final workOrder = row[4] as String;

    return FGPalletLabel(
      plateId: plateId,
      workOrder: workOrder,
      rawValue: rawValue,
      checkIn: checkIn,
    );
  }

  Future<List<FGPalletLabel>> searchByPlateId(String plateId) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.check_in,
          l.label_type,
          fpl.raw_value,
          fpl.plate_id,
          fpl.work_order
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        WHERE l.label_type = @labelType
        AND fpl.plate_id ILIKE @pattern
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'pattern': '%$plateId%',
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching FG pallet labels by plate ID: $e');
      throw Exception('Failed to search FG pallet labels: $e');
    }
  }

  Future<List<FGPalletLabel>> searchByWorkOrder(String workOrder) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.check_in,
          l.label_type,
          fpl.raw_value,
          fpl.plate_id,
          fpl.work_order
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        WHERE l.label_type = @labelType
        AND fpl.work_order ILIKE @pattern
        ORDER BY l.check_in DESC
        ''',
        substitutionValues: {
          'labelType': labelType,
          'pattern': '%$workOrder%',
        }
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error searching FG pallet labels by work order: $e');
      throw Exception('Failed to search FG pallet labels: $e');
    }
  }
}