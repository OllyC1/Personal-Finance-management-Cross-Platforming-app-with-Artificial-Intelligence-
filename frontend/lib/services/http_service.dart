import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart'; // Import your AuthService

class HttpService {
  final String baseUrl = 'http://localhost:5000';
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final AuthService _authService = AuthService();

  Future<String?> getAuthToken() async {
  try {
    // Always try to get a fresh token first
    String? token = await _authService.getIdToken(forceRefresh: true);
    
    // If that fails, fall back to the stored token
    if (token == null) {
      token = await _secureStorage.read(key: 'authToken');
      //print('Using stored token: ${token?.substring(0, Math.min(10, token?.length ?? 0))}...');
    } else {
      //print('Using fresh token: ${token.substring(0, Math.min(10, token.length))}...');
    }
    
    return token;
  } catch (e) {
    print('Error getting auth token: $e');
    return null;
  }
}

  Future<Map<String, String>> getHeaders() async {
    final token = await getAuthToken();
    
    if (token == null) {
      print('WARNING: No auth token available');
    } else {
      //print('Using token: ${token.substring(0, Math.min(10, token.length))}...'); // Prevent substring error
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await getHeaders();
      print('Making GET request to: $baseUrl/$endpoint');
      print('Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('GET request error: $e');
      throw Exception('Failed to fetch data: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('POST request error: $e');
      throw Exception('Failed to submit data: $e');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('PUT request error: $e');
      throw Exception('Failed to update data: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('DELETE request error: $e');
      throw Exception('Failed to delete data: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');
  
  if (response.statusCode >= 200 && response.statusCode < 300) {
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body);
  } else if (response.statusCode == 401) {
    // Handle unauthorized errors specifically
    print('Unauthorized error detected. Token may be invalid or expired.');
    throw Exception('Unauthorized: Invalid or expired token. Please log in again.');
  } else {
    String errorMessage;
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['message'] ?? 'Unknown error occurred';
    } catch (e) {
      errorMessage = 'Error: ${response.statusCode}';
    }
    throw Exception(errorMessage);
  }
}
}