import '../models/paper_roll_location_label.dart';
import '../services/api_service.dart';

class PaperRollLocationLabelService {
  final ApiService _api = ApiService();
  static final PaperRollLocationLabelService _instance =
      PaperRollLocationLabelService._internal();

  factory PaperRollLocationLabelService() => _instance;

  PaperRollLocationLabelService._internal();

  Future<PaperRollLocationLabel> create(PaperRollLocationLabel label) async {
    try {
      final response = await _api.post(
        ApiService.paperRollLocationEndpoint,
        {
          'locationId': label.locationId,
        },
      );

      return PaperRollLocationLabel.fromMap({
        'location_id': response['data']['locationId'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PaperRollLocationLabel>> list({
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
        ApiService.paperRollLocationEndpoint,
        queryParams: queryParams,
      );


      return (response['data'] as List).map((item) {

        final locationId = item['locationId'] ?? item['location_id'] ?? '';

        final label = PaperRollLocationLabel(
          locationId: locationId,
          checkIn: DateTime.parse(item['checkIn'] ??
              item['check_in'] ??
              DateTime.now().toIso8601String()),
          status: item['status'],
          statusUpdatedAt: item['status_updated_at'] != null
              ? DateTime.parse(item['status_updated_at'])
              : null,
          statusNotes: item['status_notes'],
          metadata: item['metadata'],
        );

        return label;
      }).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaperRollLocationLabel?> getById(String locationId) async {
    try {
      final response =
          await _api.get('${ApiService.paperRollLocationEndpoint}/$locationId');

      if (response['data'] == null) return null;

      return PaperRollLocationLabel.fromMap({
        'location_id': response['data']['locationId'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStatus(String locationId, String status,
      {String? notes}) async {
    try {
      await _api.put(
        '${ApiService.paperRollLocationEndpoint}/$locationId/status',
        {
          'status': status,
          if (notes != null) 'notes': notes,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String locationId) async {
    try {
      await _api.delete('${ApiService.paperRollLocationEndpoint}/$locationId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Row-based search and management
  Future<List<PaperRollLocationLabel>> searchByRow(String row) async {
    try {
      final response = await _api.get(
        ApiService.paperRollLocationEndpoint,
        queryParams: {'row': row},
      );

      return (response['data'] as List)
          .map((item) => PaperRollLocationLabel.fromMap({
                'location_id': item['locationId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, List<String>>> getLocationMap() async {
    try {
      final response = await _api
          .get('${ApiService.paperRollLocationEndpoint}/location-map');
      return Map<String, List<String>>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, int>> getRowOccupancy() async {
    try {
      final response = await _api
          .get('${ApiService.paperRollLocationEndpoint}/row-occupancy');
      return Map<String, int>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Batch operations
  Future<List<PaperRollLocationLabel>> createBatch(
      List<PaperRollLocationLabel> labels) async {
    try {
      final response = await _api.post(
        '${ApiService.paperRollLocationEndpoint}/batch',
        {
          'labels': labels
              .map((label) => {
                    'locationId': label.locationId,
                  })
              .toList(),
        },
      );

      return (response['data'] as List)
          .map((item) => PaperRollLocationLabel.fromMap({
                'location_id': item['locationId'],
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
    String? row,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (row != null) {
        queryParams['row'] = row;
      }

      final response = await _api.get(
        '${ApiService.paperRollLocationEndpoint}/statistics',
        queryParams: queryParams,
      );

      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Validation and utility methods
  bool isValidLocationId(String locationId) {
    return locationId.length == 2 && RegExp(r'^[A-Z]\d$').hasMatch(locationId);
  }

  String? getRowFromLocationId(String locationId) {
    return isValidLocationId(locationId) ? locationId[0] : null;
  }

  String? getPositionFromLocationId(String locationId) {
    return isValidLocationId(locationId) ? locationId[1] : null;
  }

  bool isValidRow(String row) {
    return row.length == 1 && RegExp(r'^[A-Z]$').hasMatch(row);
  }

  bool isValidPosition(String position) {
    return position.length == 1 && RegExp(r'^\d$').hasMatch(position);
  }

  // Helper methods for location management
  List<String> generateLocationsForRow(String row) {
    if (!isValidRow(row)) {
      throw ArgumentError('Invalid row identifier');
    }
    return List.generate(10, (i) => '$row$i');
  }

  // Row capacity planning
  Future<Map<String, dynamic>> getRowCapacity(String row) async {
    try {
      final response = await _api
          .get('${ApiService.paperRollLocationEndpoint}/rows/$row/capacity');
      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> getAvailablePositions(String row) async {
    try {
      final response = await _api
          .get('${ApiService.paperRollLocationEndpoint}/rows/$row/available');
      return List<String>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Complex operations
  Future<Map<String, dynamic>> optimizeLocations() async {
    try {
      final response = await _api
          .post('${ApiService.paperRollLocationEndpoint}/optimize', {});
      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, List<String>>> suggestReorganization() async {
    try {
      final response = await _api.get(
          '${ApiService.paperRollLocationEndpoint}/suggest-reorganization');
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
}
