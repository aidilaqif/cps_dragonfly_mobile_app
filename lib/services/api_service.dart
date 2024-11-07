import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal();

  // Base URL from environment variables
  final String baseUrl = dotenv.env['API_URL'] ?? '';

  // Headers for all requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async {
    try {
      // Print debug information
      print('Making GET request to: $baseUrl$endpoint');
      if (queryParams != null) {
        print('Query parameters: $queryParams');
      }

      final uri =
          Uri.parse(baseUrl + endpoint).replace(queryParameters: queryParams);
      print('Full URL: $uri');

      final response = await http
          .get(
        uri,
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('The request timed out');
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received from server');
        }
        try {
          return json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse server response: $e');
        }
      } else {
        final errorBody = _parseErrorBody(response.body);
        throw Exception(
            'Server returned ${response.statusCode}: ${errorBody ?? response.reasonPhrase}');
      }
    } catch (e) {
      print('API Service Error: $e');
      if (e is TimeoutException) {
        throw Exception(
            'Request timed out. Please check your internet connection.');
      }
      if (e is http.ClientException) {
        throw Exception(
            'Network error: Unable to connect to server. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse(baseUrl + endpoint);
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse(baseUrl + endpoint);
      final response = await http.put(
        uri,
        headers: _headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse(baseUrl + endpoint);
      final response = await http.delete(uri, headers: _headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Error handling
  Exception _handleError(http.Response response) {
    try {
      final error = json.decode(response.body);
      return Exception(error['message'] ?? 'Unknown error occurred');
    } catch (e) {
      return Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  String? _parseErrorBody(String body) {
    try {
      final parsed = json.decode(body);
      return parsed['message'] ?? parsed['error'];
    } catch (_) {
      return null;
    }
  }

  // API Endpoints
  static const String fgPalletEndpoint = '/fg-pallet';
  static const String rollEndpoint = '/roll';
  static const String fgLocationEndpoint = '/fg-location';
  static const String paperRollLocationEndpoint = '/paper-roll-location';
  static const String exportEndpoint = '/exportToCSV/labels';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
