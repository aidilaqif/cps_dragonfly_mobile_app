import '../models/fg_pallet_label.dart';
import '../services/api_service.dart';

class FGPalletLabelService {
  final ApiService _api = ApiService();
  static final FGPalletLabelService _instance =
      FGPalletLabelService._internal();

  factory FGPalletLabelService() => _instance;

  FGPalletLabelService._internal();

  Future<FGPalletLabel> create(FGPalletLabel label) async {
    try {
      final response = await _api.post(
        ApiService.fgPalletEndpoint,
        {
          'plateId': label.plateId,
          'workOrder': label.workOrder,
          'rawValue': label.rawValue,
        },
      );

      return FGPalletLabel.fromMap({
        'plate_id': response['data']['plateId'],
        'work_order': response['data']['workOrder'],
        'raw_value': response['data']['rawValue'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FGPalletLabel>> list({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
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
        ApiService.fgPalletEndpoint,
        queryParams: queryParams,
      );

      final data = response['data'] as List;

      return data.map((item) {
        // Try to get values with different possible field names
        final plateId = item['plate_id'] ?? item['plateId'] ?? '';
        final workOrder = item['work_order'] ?? item['workOrder'] ?? '';
        final rawValue = item['raw_value'] ?? item['rawValue'] ?? '';
        final checkIn = item['check_in'] ??
            item['checkIn'] ??
            DateTime.now().toIso8601String();

        return FGPalletLabel(
          plateId: plateId,
          workOrder: workOrder,
          rawValue: rawValue,
          checkIn: DateTime.parse(checkIn),
          status: item['status'],
          statusUpdatedAt: item['status_updated_at'] != null ||
                  item['statusUpdatedAt'] != null
              ? DateTime.parse(
                  item['status_updated_at'] ?? item['statusUpdatedAt'])
              : null,
          statusNotes: item['status_notes'] ?? item['statusNotes'],
        );
      }).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<FGPalletLabel?> getById(String plateId) async {
    try {
      final response =
          await _api.get('${ApiService.fgPalletEndpoint}/$plateId');

      if (response['data'] == null) return null;

      return FGPalletLabel.fromMap({
        'plate_id': response['data']['plateId'],
        'work_order': response['data']['workOrder'],
        'raw_value': response['data']['rawValue'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStatus(String plateId, String status,
      {String? notes}) async {
    try {
      await _api.put(
        '${ApiService.fgPalletEndpoint}/$plateId/status',
        {
          'status': status,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String plateId) async {
    try {
      await _api.delete('${ApiService.fgPalletEndpoint}/$plateId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Advanced search methods
  Future<List<FGPalletLabel>> searchByPlateId(String plateId) async {
    try {
      final response = await _api.get(
        ApiService.fgPalletEndpoint,
        queryParams: {'plateId': plateId},
      );

      return (response['data'] as List)
          .map((item) => FGPalletLabel.fromMap({
                'plate_id': item['plateId'],
                'work_order': item['workOrder'],
                'raw_value': item['rawValue'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FGPalletLabel>> searchByWorkOrder(String workOrder) async {
    try {
      final response = await _api.get(
        ApiService.fgPalletEndpoint,
        queryParams: {'workOrder': workOrder},
      );

      return (response['data'] as List)
          .map((item) => FGPalletLabel.fromMap({
                'plate_id': item['plateId'],
                'work_order': item['workOrder'],
                'raw_value': item['rawValue'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Batch operations
  Future<List<FGPalletLabel>> createBatch(List<FGPalletLabel> labels) async {
    try {
      final response = await _api.post(
        '${ApiService.fgPalletEndpoint}/batch',
        {
          'labels': labels
              .map((label) => {
                    'plateId': label.plateId,
                    'workOrder': label.workOrder,
                    'rawValue': label.rawValue,
                  })
              .toList(),
        },
      );

      return (response['data'] as List)
          .map((item) => FGPalletLabel.fromMap({
                'plate_id': item['plateId'],
                'work_order': item['workOrder'],
                'raw_value': item['rawValue'],
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
        '${ApiService.fgPalletEndpoint}/statistics',
        queryParams: queryParams,
      );

      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Validation methods
  bool isValidPlateId(String plateId) {
    return plateId.length == 11 && plateId.contains('-');
  }

  bool isValidWorkOrder(String workOrder) {
    final pattern = RegExp(r'^\d{2}-\d{4}-\d{5}$');
    return pattern.hasMatch(workOrder);
  }

  // Error handling
  Exception _handleError(dynamic error) {
    if (error is Exception) {
      return error;
    }
    return Exception('An unexpected error occurred: $error');
  }

  // Helper methods for data transformation
  Map<String, dynamic> _transformToApiFormat(FGPalletLabel label) {
    return {
      'plateId': label.plateId,
      'workOrder': label.workOrder,
      'rawValue': label.rawValue,
    };
  }

  FGPalletLabel _transformFromApiResponse(Map<String, dynamic> response) {
    return FGPalletLabel.fromMap({
      'plate_id': response['plateId'],
      'work_order': response['workOrder'],
      'raw_value': response['rawValue'],
      'check_in': response['checkIn'],
    });
  }
}
