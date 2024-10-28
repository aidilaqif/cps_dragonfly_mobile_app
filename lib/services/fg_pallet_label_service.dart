import 'package:postgres/postgres.dart';
import '../models/fg_pallet_label.dart';
import 'label_service.dart';

class FGPalletLabelService extends BaseLabelService<FGPalletLabel> {
  FGPalletLabelService(PostgreSQLConnection connection) 
    : super(
        connection, 
        'fg_pallet',  // labelType
        'fg_pallet_labels'  // tableName
      );

  @override
  Map<String, dynamic> getLabelValues(FGPalletLabel label) {
    return {
      'plate_id': label.plateId,
      'work_order': label.workOrder,
    };
  }

  @override
  List<String> getSpecificColumns() {
    return ['plate_id', 'work_order', 'raw_value'];
  }

  @override
  Map<String, dynamic> getSpecificValues(FGPalletLabel label) {
    return {
      'plate_id': label.plateId,
      'work_order': label.workOrder,
      'raw_value': label.rawValue,
    };
  }

  @override
  FGPalletLabel createLabelFromRow(List<dynamic> row) {
    final scanTime = row[0] is String 
        ? DateTime.parse(row[0] as String)
        : (row[0] as DateTime).toLocal();
    
    final isRescan = row[1] as bool;
    final sessionId = row[2] as int;
    final metadata = row[3] as Map<String, dynamic>?;
    final plateId = row[4] as String;
    final workOrder = row[5] as String;

    return FGPalletLabel(
      plateId: plateId,
      workOrder: workOrder,
      timeLog: scanTime,
      rawValue: '$plateId-$workOrder',
      isRescan: isRescan,
      sessionId: sessionId.toString(),
      metadata: metadata,
    );
  }

  // Additional methods specific to FG Pallet Labels

  Future<List<FGPalletLabel>> searchByPlateId(String plateId) async {
    try {
      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          fpl.plate_id,
          fpl.work_order
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        WHERE l.label_type = @labelType
        AND fpl.plate_id ILIKE @pattern
        ORDER BY l.scan_time DESC
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
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          fpl.plate_id,
          fpl.work_order
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
        WHERE l.label_type = @labelType
        AND fpl.work_order ILIKE @pattern
        ORDER BY l.scan_time DESC
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

  Future<Map<String, List<String>>> getWorkOrdersByPlateId() async {
    try {
      final results = await connection.query(
        '''
        SELECT DISTINCT plate_id, work_order
        FROM fg_pallet_labels
        ORDER BY plate_id, work_order
        '''
      );

      Map<String, List<String>> mapping = {};
      for (final row in results) {
        final plateId = row[0] as String;
        final workOrder = row[1] as String;
        mapping.putIfAbsent(plateId, () => []).add(workOrder);
      }

      return mapping;
    } catch (e) {
      print('Error getting work orders by plate ID: $e');
      throw Exception('Failed to get work orders mapping: $e');
    }
  }

  Future<Map<String, dynamic>> getPlateStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        SELECT 
          COUNT(DISTINCT plate_id) as unique_plates,
          COUNT(DISTINCT work_order) as unique_work_orders,
          COUNT(*) as total_scans,
          COUNT(*) FILTER (WHERE l.is_rescan) as rescan_count,
          AVG(ARRAY_LENGTH(
            JSONB_ARRAY_ELEMENTS(
              CASE 
                WHEN l.metadata->'rescan_history' IS NOT NULL 
                THEN l.metadata->'rescan_history' 
                ELSE '[]'::jsonb 
              END
            ),1
          )) as avg_rescans_per_plate
        FROM labels l
        JOIN fg_pallet_labels fpl ON l.id = fpl.label_id
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

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      if (results.isEmpty) return {};

      return {
        'unique_plates': results.first[0],
        'unique_work_orders': results.first[1],
        'total_scans': results.first[2],
        'rescan_count': results.first[3],
        'avg_rescans_per_plate': results.first[4],
      };
    } catch (e) {
      print('Error getting plate statistics: $e');
      throw Exception('Failed to get plate statistics: $e');
    }
  }
}