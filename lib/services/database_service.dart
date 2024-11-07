import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static String? _baseUrl;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  // Initialize the service with configuration
  Future<void> initialize() async {
    _baseUrl = dotenv.env['API_BASE_URL'];
  }

  // Get base URL
  String get baseUrl {
    if (_baseUrl == null) {
      throw Exception('DatabaseService not initialized. Call initialize() first.');
    }
    return _baseUrl!;
  }

  // Create HTTP client with default headers
  http.Client createClient() {
    final client = http.Client();
    return client;
  }

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http.put(
        uri,
        headers: _getHeaders(),
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      final response = await http.delete(
        uri,
        headers: _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Default headers for requests
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // if (_apiKey != null) {
    //   headers['Authorization'] = 'Bearer $_apiKey';
    // }

    return headers;
  }

  // Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body);
    }

    switch (response.statusCode) {
      case 400:
        throw Exception('Bad request: ${_parseErrorMessage(response)}');
      case 401:
        throw Exception('Unauthorized: ${_parseErrorMessage(response)}');
      case 403:
        throw Exception('Forbidden: ${_parseErrorMessage(response)}');
      case 404:
        throw Exception('Not found: ${_parseErrorMessage(response)}');
      case 500:
        throw Exception('Server error: ${_parseErrorMessage(response)}');
      default:
        throw Exception('Unknown error: ${response.statusCode}');
    }
  }

  // Parse error message from response
  String _parseErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      return body['message'] ?? body['error'] ?? 'Unknown error';
    } catch (e) {
      return response.body;
    }
  }

  // Handle general errors
  Exception _handleError(dynamic error) {
    if (error is TimeoutException) {
      return Exception('Request timed out');
    }
    if (error is http.ClientException) {
      return Exception('Network error: ${error.message}');
    }
    return Exception('Error: ${error.toString()}');
  }

  // API Endpoints
  static const String endpointFgPallet = 'fg-pallet';
  static const String endpointRoll = 'roll';
  static const String endpointFgLocation = 'fg-location';
  static const String endpointPaperRollLocation = 'paper-roll-location';
  static const String endpointExport = 'exportToCSV';
}