import '../models/roll_label.dart';
import '../services/api_service.dart';

class RollLabelService {
  final ApiService _api = ApiService();
  static final RollLabelService _instance = RollLabelService._internal();

  factory RollLabelService() => _instance;

  RollLabelService._internal();

  Future<RollLabel> create(RollLabel label) async {
    try {
      final response = await _api.post(
        ApiService.rollEndpoint,
        {
          'rollId': label.rollId,
        },
      );

      return RollLabel.fromMap({
        'roll_id': response['data']['rollId'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<RollLabel>> list({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? batchNumber,
    String? sequenceRange,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _api.get(
        ApiService.rollEndpoint,
        queryParams: queryParams,
      );

      // Make sure we're properly mapping all fields
      return (response['data'] as List)
          .map((item) => RollLabel.fromMap({
                'roll_id': item['roll_id'],
                'check_in': item['check_in'],
                'status': item['status'],
                'status_updated_at': item['status_updated_at'],
                'status_notes': item['status_notes'],
                'metadata': {
                  'batch': item['roll_id']?.substring(0, 2),
                  'sequence': item['roll_id']?.substring(3),
                },
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<RollLabel?> getById(String rollId) async {
    try {
      final response = await _api.get('${ApiService.rollEndpoint}/$rollId');

      if (response['data'] == null) return null;

      return RollLabel.fromMap({
        'roll_id': response['data']['rollId'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStatus(String rollId, String status,
      {String? notes}) async {
    try {
      await _api.put(
        '${ApiService.rollEndpoint}/$rollId/status',
        {
          'status': status,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String rollId) async {
    try {
      await _api.delete('${ApiService.rollEndpoint}/$rollId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Advanced search methods
  Future<List<RollLabel>> searchByBatchNumber(String batchNumber) async {
    try {
      final response = await _api.get(
        ApiService.rollEndpoint,
        queryParams: {'batchNumber': batchNumber},
      );

      return (response['data'] as List)
          .map((item) => RollLabel.fromMap({
                'roll_id': item['rollId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<RollLabel>> searchBySequenceRange(
    String startSequence,
    String endSequence,
  ) async {
    try {
      final response = await _api.get(
        ApiService.rollEndpoint,
        queryParams: {
          'startSequence': startSequence,
          'endSequence': endSequence,
        },
      );

      return (response['data'] as List)
          .map((item) => RollLabel.fromMap({
                'roll_id': item['rollId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Batch operations
  Future<List<RollLabel>> createBatch(List<RollLabel> labels) async {
    try {
      final response = await _api.post(
        '${ApiService.rollEndpoint}/batch',
        {
          'labels': labels
              .map((label) => {
                    'rollId': label.rollId,
                  })
              .toList(),
        },
      );

      return (response['data'] as List)
          .map((item) => RollLabel.fromMap({
                'roll_id': item['rollId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? batchNumber,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (batchNumber != null) {
        queryParams['batchNumber'] = batchNumber;
      }

      final response = await _api.get(
        '${ApiService.rollEndpoint}/statistics',
        queryParams: queryParams,
      );

      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Validation methods
  bool isValidRollId(String rollId) {
    // Format: 2 digits + 1 letter + 5 digits
    final pattern = RegExp(r'^\d{2}[A-Z]\d{5}$');
    return pattern.hasMatch(rollId);
  }

  bool isValidBatchNumber(String batchNumber) {
    // Format: 2 digits
    final pattern = RegExp(r'^\d{2}$');
    return pattern.hasMatch(batchNumber);
  }

  bool isValidSequenceNumber(String sequenceNumber) {
    // Format: 5 digits
    final pattern = RegExp(r'^\d{5}$');
    return pattern.hasMatch(sequenceNumber);
  }

  // Roll-specific utility methods
  String extractBatchNumber(String rollId) {
    return rollId.substring(0, 2);
  }

  String extractSequenceNumber(String rollId) {
    return rollId.substring(3);
  }

  Future<Map<String, List<String>>> getBatchSequenceMap({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await _api.get(
        '${ApiService.rollEndpoint}/batch-sequence-map',
        queryParams: queryParams,
      );

      return Map<String, List<String>>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Error handling
  Exception _handleError(dynamic error) {
    if (error is Exception) {
      return error;
    }
    return Exception('An unexpected error occurred: $error');
  }

  // Helper methods for data transformation
  Map<String, dynamic> _transformToApiFormat(RollLabel label) {
    return {
      'rollId': label.rollId,
    };
  }

  RollLabel _transformFromApiResponse(Map<String, dynamic> response) {
    return RollLabel.fromMap({
      'roll_id': response['rollId'],
      'check_in': response['checkIn'],
    });
  }

  // Additional utility methods for roll-specific operations
  Future<List<String>> getAvailableBatches() async {
    try {
      final response = await _api.get('${ApiService.rollEndpoint}/batches');
      return List<String>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> getSequencesForBatch(String batchNumber) async {
    try {
      final response = await _api.get(
        '${ApiService.rollEndpoint}/batches/$batchNumber/sequences',
      );
      return List<String>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }
}
