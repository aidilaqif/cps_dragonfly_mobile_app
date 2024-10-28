import 'package:postgres/postgres.dart';
import '../models/label_types.dart';

abstract class BaseLabelService<T> {
  final PostgreSQLConnection connection;
  final String labelType;
  final String tableName;
  
  BaseLabelService(this.connection, this.labelType, this.tableName);

  // Abstract methods that must be implemented by specific label services
  Map<String, dynamic> getLabelValues(T label);
  T createLabelFromRow(List<dynamic> row);
  List<String> getSpecificColumns();
  Map<String, dynamic> getSpecificValues(T label);

  Future<T> create(T label, int sessionId) async {
    try {
      return await connection.transaction((ctx) async {
        // Check for existing label
        final existingLabel = await _findExistingLabel(ctx, label);
        
        if (existingLabel != null) {
          // Update existing label
          await _updateExistingLabel(ctx, existingLabel['label_id'], label, sessionId);
          return label;
        }

        // Create new label
        final labelId = await _createNewLabel(ctx, label, sessionId);
        await _createSpecificLabel(ctx, labelId, label);
        
        return label;
      });
    } catch (e) {
      print('Error in BaseLabelService.create: $e');
      throw Exception('Failed to create/update $labelType label: $e');
    }
  }

  Future<Map<String, dynamic>?> _findExistingLabel(
    PostgreSQLExecutionContext ctx,
    T label,
  ) async {
    final values = getLabelValues(label);
    final conditions = values.keys
        .map((key) => '$key = @$key')
        .join(' AND ');

    final result = await ctx.query(
      '''
      SELECT l.id as label_id, l.session_id, l.scan_time, l.is_rescan
      FROM labels l
      JOIN $tableName sl ON l.id = sl.label_id
      WHERE $conditions
      ''',
      substitutionValues: values,
    );

    if (result.isEmpty) return null;
    return {
      'label_id': result.first[0],
      'session_id': result.first[1],
      'scan_time': result.first[2],
      'is_rescan': result.first[3],
    };
  }

  Future<void> _updateExistingLabel(
    PostgreSQLExecutionContext ctx,
    int labelId,
    T label,
    int sessionId,
  ) async {
    final currentTime = DateTime.now().toUtc();
    
    await ctx.query(
      '''
      UPDATE labels 
      SET scan_time = @scanTime,
          session_id = @sessionId,
          is_rescan = true,
          metadata = metadata || @newMetadata::jsonb
      WHERE id = @labelId
      ''',
      substitutionValues: {
        'labelId': labelId,
        'scanTime': currentTime,
        'sessionId': sessionId,
        'newMetadata': {
          'rescan_history': [
            {
              'scan_time': currentTime.toIso8601String(),
              'session_id': sessionId,
            }
          ]
        }
      },
    );
  }

  Future<int> _createNewLabel(
    PostgreSQLExecutionContext ctx,
    T label,
    int sessionId,
  ) async {
    final result = await ctx.query(
      '''
      INSERT INTO labels (
        session_id, 
        label_type, 
        scan_time, 
        is_rescan,
        metadata
      )
      VALUES (
        @sessionId,
        @labelType,
        @scanTime,
        @isRescan,
        @metadata
      )
      RETURNING id
      ''',
      substitutionValues: {
        'sessionId': sessionId,
        'labelType': labelType,
        'scanTime': DateTime.now().toUtc(),
        'isRescan': false,
        'metadata': {
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'initial_session_id': sessionId,
        }
      },
    );

    if (result.isEmpty) {
      throw Exception('Failed to insert label record');
    }

    return result.first[0] as int;
  }

  Future<void> _createSpecificLabel(
    PostgreSQLExecutionContext ctx,
    int labelId,
    T label,
  ) async {
    final specificValues = getSpecificValues(label);
    final columns = ['label_id', ...getSpecificColumns()];
    final valuePlaceholders = columns.map((col) => '@$col').join(', ');

    await ctx.query(
      '''
      INSERT INTO $tableName (${columns.join(', ')})
      VALUES ($valuePlaceholders)
      ''',
      substitutionValues: {
        'label_id': labelId,
        ...specificValues,
      },
    );
  }

  Future<List<T>> list({
    DateTime? startDate,
    DateTime? endDate,  // Changed from toDate to endDate
    bool includeRescans = true,
    String? sessionId,
  }) async {
    try {
      final specificColumns = getSpecificColumns()
          .map((col) => 'sl.$col')
          .join(', ');

      String query = '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          $specificColumns
        FROM labels l
        JOIN $tableName sl ON l.id = sl.label_id
        WHERE l.label_type = @labelType
      ''';

      final Map<String, dynamic> substitutionValues = {
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

      if (!includeRescans) {
        query += ' AND NOT l.is_rescan';
      }

      if (sessionId != null) {
        query += ' AND l.session_id = @sessionId';
        substitutionValues['sessionId'] = int.parse(sessionId);
      }

      query += ' ORDER BY l.scan_time DESC';

      final results = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return results.map((row) => createLabelFromRow(row)).toList();
    } catch (e) {
      print('Error in BaseLabelService.list: $e');
      throw Exception('Failed to list $labelType labels: $e');
    }
  }
  Future<T?> read(String id) async {
    try {
      final specificColumns = getSpecificColumns()
          .map((col) => 'sl.$col')
          .join(', ');

      final results = await connection.query(
        '''
        SELECT 
          l.scan_time,
          l.is_rescan,
          l.session_id,
          l.metadata,
          $specificColumns
        FROM labels l
        JOIN $tableName sl ON l.id = sl.label_id
        WHERE l.label_type = @labelType
        AND sl.${getSpecificColumns().first} = @id
        ORDER BY l.scan_time DESC
        LIMIT 1
        ''',
        substitutionValues: {
          'labelType': labelType,
          'id': id,
        },
      );

      if (results.isEmpty) return null;
      return createLabelFromRow(results.first);
    } catch (e) {
      print('Error in BaseLabelService.read: $e');
      throw Exception('Failed to read $labelType label: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRescanStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String query = '''
        WITH rescan_data AS (
          SELECT 
            l.scan_time,
            l.session_id,
            l.is_rescan,
            LAG(l.scan_time) OVER (
              PARTITION BY ${getSpecificColumns().first} 
              ORDER BY l.scan_time
            ) as previous_scan
          FROM labels l
          JOIN $tableName sl ON l.id = sl.label_id
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
        )
        SELECT 
          COUNT(*) FILTER (WHERE is_rescan) as rescan_count,
          AVG(EXTRACT(EPOCH FROM (scan_time - previous_scan))) 
            FILTER (WHERE is_rescan) as avg_rescan_interval,
          MIN(EXTRACT(EPOCH FROM (scan_time - previous_scan))) 
            FILTER (WHERE is_rescan) as min_rescan_interval,
          MAX(EXTRACT(EPOCH FROM (scan_time - previous_scan))) 
            FILTER (WHERE is_rescan) as max_rescan_interval,
          COUNT(DISTINCT session_id) as unique_sessions
        FROM rescan_data
      ''';

      final results = await connection.query(query, substitutionValues: substitutionValues);
      
      if (results.isEmpty) return [];

      return [{
        'rescan_count': results.first[0],
        'avg_interval_seconds': results.first[1],
        'min_interval_seconds': results.first[2],
        'max_interval_seconds': results.first[3],
        'unique_sessions': results.first[4],
      }];
    } catch (e) {
      print('Error in BaseLabelService.getRescanStats: $e');
      throw Exception('Failed to get rescan stats for $labelType labels: $e');
    }
  }

  Future<bool> delete(String id) async {
    try {
      return await connection.transaction((ctx) async {
        final result = await ctx.query(
          '''
          DELETE FROM labels l
          USING $tableName sl
          WHERE l.id = sl.label_id
          AND sl.${getSpecificColumns().first} = @id
          RETURNING l.id
          ''',
          substitutionValues: {
            'id': id,
          },
        );

        return result.isNotEmpty;
      });
    } catch (e) {
      print('Error in BaseLabelService.delete: $e');
      throw Exception('Failed to delete $labelType label: $e');
    }
  }
}