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

  Future<T> create(T label) async {
    try {
      return await connection.transaction((ctx) async {
        // Check for existing label
        final existingLabel = await _findExistingLabel(ctx, label);
        
        if (existingLabel != null) {
          // Update existing label's check_in time
          await _updateExistingLabel(ctx, existingLabel['label_id'], label);
          return label;
        }

        // Create new label
        final labelId = await _createNewLabel(ctx, label);
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
      SELECT l.id as label_id, l.check_in
      FROM labels l
      JOIN $tableName sl ON l.id = sl.label_id
      WHERE $conditions
      ''',
      substitutionValues: values,
    );

    if (result.isEmpty) return null;
    return {
      'label_id': result.first[0],
      'check_in': result.first[1],
    };
  }

  Future<void> _updateExistingLabel(
    PostgreSQLExecutionContext ctx,
    int labelId,
    T label,
  ) async {
    final currentTime = DateTime.now().toUtc();
    
    // Update main labels table
    await ctx.query(
      '''
      UPDATE labels 
      SET check_in = @checkIn
      WHERE id = @labelId
      ''',
      substitutionValues: {
        'labelId': labelId,
        'checkIn': currentTime,
      },
    );

    // Update specific label table
    await ctx.query(
      '''
      UPDATE $tableName 
      SET check_in = @checkIn
      WHERE label_id = @labelId
      ''',
      substitutionValues: {
        'labelId': labelId,
        'checkIn': currentTime,
      },
    );
  }

  Future<int> _createNewLabel(
    PostgreSQLExecutionContext ctx,
    T label,
  ) async {
    final result = await ctx.query(
      '''
      INSERT INTO labels (
        label_type, 
        label_id,
        check_in
      )
      VALUES (
        @labelType,
        @labelId,
        @checkIn
      )
      RETURNING id
      ''',
      substitutionValues: {
        'labelType': labelType,
        'labelId': getLabelValues(label).values.first,
        'checkIn': DateTime.now().toUtc(),
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
    final columns = ['label_id', ...getSpecificColumns(), 'check_in'];
    final valuePlaceholders = columns.map((col) => '@$col').join(', ');

    await ctx.query(
      '''
      INSERT INTO $tableName (${columns.join(', ')})
      VALUES ($valuePlaceholders)
      ''',
      substitutionValues: {
        'label_id': labelId,
        'check_in': DateTime.now().toUtc(),
        ...specificValues,
      },
    );
  }

  Future<List<T>> list({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final specificColumns = getSpecificColumns()
          .map((col) => 'sl.$col')
          .join(', ');

      String query = '''
        SELECT 
          l.check_in,
          l.label_type,
          $specificColumns
        FROM labels l
        JOIN $tableName sl ON l.id = sl.label_id
        WHERE l.label_type = @labelType
      ''';

      final Map<String, dynamic> substitutionValues = {
        'labelType': labelType,
      };

      if (startDate != null) {
        query += ' AND l.check_in >= @startDate';
        substitutionValues['startDate'] = startDate.toUtc();
      }

      if (endDate != null) {
        query += ' AND l.check_in <= @endDate';
        substitutionValues['endDate'] = endDate.toUtc();
      }

      query += ' ORDER BY l.check_in DESC';

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
          l.check_in,
          l.label_type,
          $specificColumns
        FROM labels l
        JOIN $tableName sl ON l.id = sl.label_id
        WHERE l.label_type = @labelType
        AND sl.${getSpecificColumns().first} = @id
        ORDER BY l.check_in DESC
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
}