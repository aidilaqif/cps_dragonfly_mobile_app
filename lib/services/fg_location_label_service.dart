import '../models/fg_location_label.dart';
import '../services/api_service.dart';

class FGLocationLabelService {
  final ApiService _api = ApiService();
  static final FGLocationLabelService _instance =
      FGLocationLabelService._internal();

  factory FGLocationLabelService() => _instance;

  FGLocationLabelService._internal();

  Future<FGLocationLabel> create(FGLocationLabel label) async {
    try {
      final response = await _api.post(
        ApiService.fgLocationEndpoint,
        {
          'locationId': label.locationId,
        },
      );

      return FGLocationLabel.fromMap({
        'location_id': response['data']['locationId'],
        'check_in': response['data']['checkIn'],
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FGLocationLabel>> list({
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
        ApiService.fgLocationEndpoint,
        queryParams: queryParams,
      );

      return (response['data'] as List).map((item) {

        final locationId = item['locationId'] ?? item['location_id'] ?? '';

        final label = FGLocationLabel(
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

  Future<FGLocationLabel?> getById(String locationId) async {
    try {
      final response =
          await _api.get('${ApiService.fgLocationEndpoint}/$locationId');

      if (response['data'] == null) return null;

      return FGLocationLabel.fromMap({
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
        '${ApiService.fgLocationEndpoint}/$locationId/status',
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
      await _api.delete('${ApiService.fgLocationEndpoint}/$locationId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Location-specific search methods
  Future<List<FGLocationLabel>> searchByArea(String area) async {
    try {
      final response = await _api.get(
        ApiService.fgLocationEndpoint,
        queryParams: {'area': area},
      );

      return (response['data'] as List)
          .map((item) => FGLocationLabel.fromMap({
                'location_id': item['locationId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FGLocationLabel>> getRestrictedLocations() async {
    try {
      final response = await _api.get(
        '${ApiService.fgLocationEndpoint}/restricted',
      );

      return (response['data'] as List)
          .map((item) => FGLocationLabel.fromMap({
                'location_id': item['locationId'],
                'check_in': item['checkIn'],
              }))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Area mapping and status methods
  Future<Map<String, List<String>>> getAreaMap() async {
    try {
      final response =
          await _api.get('${ApiService.fgLocationEndpoint}/area-map');
      return Map<String, List<String>>.from(response['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAreaOccupancy() async {
    try {
      final response =
          await _api.get('${ApiService.fgLocationEndpoint}/occupancy');
      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Batch operations
  Future<List<FGLocationLabel>> createBatch(
      List<FGLocationLabel> labels) async {
    try {
      final response = await _api.post(
        '${ApiService.fgLocationEndpoint}/batch',
        {
          'labels': labels
              .map((label) => {
                    'locationId': label.locationId,
                  })
              .toList(),
        },
      );

      return (response['data'] as List)
          .map((item) => FGLocationLabel.fromMap({
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
    String? area,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (area != null) {
        queryParams['area'] = area;
      }

      final response = await _api.get(
        '${ApiService.fgLocationEndpoint}/statistics',
        queryParams: queryParams,
      );

      return response['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Validation methods
  bool isValidLocationId(String locationId) {
    // Single letter (B)
    if (locationId.length == 1) {
      return RegExp(r'^[A-Z]$').hasMatch(locationId);
    }
    // Letter + two digits (B01)
    if (locationId.length == 3) {
      return RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId);
    }
    // Restricted area (RA1)
    if (locationId.length == 3) {
      return RegExp(r'^R[A-Z][1-5]$').hasMatch(locationId);
    }
    return false;
  }

  bool isRestrictedArea(String locationId) {
    return locationId.startsWith('R') && locationId.length == 3;
  }

  String getAreaType(String locationId) {
    if (locationId.length == 1) return 'main';
    if (locationId.length == 3 && RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId))
      return 'sub';
    if (RegExp(r'^R[A-Z][1-5]$').hasMatch(locationId)) return 'restricted';
    return 'unknown';
  }

  // Utility methods for location hierarchy
  String? getMainArea(String locationId) {
    if (locationId.length == 3 &&
        RegExp(r'^[A-Z]\d{2}$').hasMatch(locationId)) {
      return locationId[0];
    }
    return null;
  }

  List<String> getSubLocations(String mainArea) {
    if (mainArea.length != 1 || !RegExp(r'^[A-Z]$').hasMatch(mainArea)) {
      throw ArgumentError('Invalid main area identifier');
    }
    return List.generate(
        100, (i) => '$mainArea${i.toString().padLeft(2, '0')}');
  }

  // Error handling
  Exception _handleError(dynamic error) {
    if (error is Exception) {
      return error;
    }
    return Exception('An unexpected error occurred: $error');
  }

  // Helper methods for data transformation
  Map<String, dynamic> _transformToApiFormat(FGLocationLabel label) {
    return {
      'locationId': label.locationId,
    };
  }

  FGLocationLabel _transformFromApiResponse(Map<String, dynamic> response) {
    return FGLocationLabel.fromMap({
      'location_id': response['locationId'],
      'check_in': response['checkIn'],
    });
  }
}
