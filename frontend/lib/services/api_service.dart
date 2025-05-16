import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/transaction.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return 'http://10.0.2.2:5000';
        } else if (Platform.isIOS) {
          return 'http://localhost:5000';
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return 'http://localhost:5000';
        }
      } catch (e) {
        print('Platform detection failed: $e');
      }
    }
    
    return 'http://localhost:5000';
  }

  // Get auth token from secure storage
  Future<String?> getAuthToken({bool forceRefresh = false}) async {
    return await _secureStorage.read(key: 'authToken');
  }

  // Test connection to verify API is reachable
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl');
      final response = await http.get(
        Uri.parse('$baseUrl/health'), // Create a simple health endpoint on your server
      ).timeout(const Duration(seconds: 5));
      
      print('Test connection status: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Generic GET request with auth token
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final Uri uri = queryParams != null 
          ? Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams)
          : Uri.parse('$baseUrl$endpoint');
      
      print('GET request to: $uri');
      
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final freshToken = await getAuthToken(forceRefresh: true);
        if (freshToken != null) {
          final retryResponse = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $freshToken'},
          );
          
          if (retryResponse.statusCode == 200) {
            return json.decode(retryResponse.body);
          }
        }
        throw Exception('Authentication failed: ${response.statusCode}');
      } else {
        print('Request failed: ${response.body}');
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in GET request: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request with auth token
  Future<dynamic> post(String endpoint, dynamic data) async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      print('POST request to: $baseUrl$endpoint');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final freshToken = await getAuthToken(forceRefresh: true);
        if (freshToken != null) {
          final retryResponse = await http.post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $freshToken',
            },
            body: json.encode(data),
          );
          
          if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
            return json.decode(retryResponse.body);
          }
        }
        throw Exception('Authentication failed: ${response.statusCode}');
      } else {
        print('Request failed: ${response.body}');
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in POST request: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic PUT request with auth token
  Future<dynamic> put(String endpoint, dynamic data) async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      print('PUT request to: $baseUrl$endpoint');
      
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final freshToken = await getAuthToken(forceRefresh: true);
        if (freshToken != null) {
          final retryResponse = await http.put(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $freshToken',
            },
            body: json.encode(data),
          );
          
          if (retryResponse.statusCode == 200) {
            return json.decode(retryResponse.body);
          }
        }
        throw Exception('Authentication failed: ${response.statusCode}');
      } else {
        print('Request failed: ${response.body}');
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in PUT request: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic DELETE request with auth token
  Future<dynamic> delete(String endpoint) async {
    try {
      final token = await getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      print('DELETE request to: $baseUrl$endpoint');
      
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final freshToken = await getAuthToken(forceRefresh: true);
        if (freshToken != null) {
          final retryResponse = await http.delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Authorization': 'Bearer $freshToken'},
          );
          
          if (retryResponse.statusCode == 200) {
            return json.decode(retryResponse.body);
          }
        }
        throw Exception('Authentication failed: ${response.statusCode}');
      } else {
        print('Request failed: ${response.body}');
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in DELETE request: $e');
      throw Exception('Network error: $e');
    }
  }

  // Specific API methods for your app

  // User methods
  Future<Map<String, dynamic>> getUserProfile() async {
    return await get('/users/me');
  }

  // Transaction methods
  Future<List<Transaction>> getTransactions() async {
    try {
      final jsonResponse = await get('/transactions');
      if (jsonResponse is List) {
        return jsonResponse.map((data) => Transaction.fromJson(data)).toList();
      }
      throw Exception('Invalid response format');
    } catch (e) {
      print('Error fetching transactions: $e');
      throw Exception('Failed to load transactions: $e');
    }
  }

  Future<dynamic> addTransaction(Transaction transaction) async {
    return await post('/transactions', transaction.toJson());
  }

  // Income methods
  Future<List<dynamic>> getIncome({String? month}) async {
    try {
      final Map<String, String>? queryParams = month != null ? {'month': month} : null;
      final jsonResponse = await get('/income', queryParams: queryParams);
      return jsonResponse;
    } catch (e) {
      print('Error fetching income: $e');
      throw Exception('Failed to load income: $e');
    }
  }

  Future<dynamic> addIncome(Map<String, dynamic> incomeData) async {
    return await post('/income', incomeData);
  }

  Future<dynamic> updateIncome(String id, Map<String, dynamic> incomeData) async {
    return await put('/income/$id', incomeData);
  }

  Future<dynamic> deleteIncome(String id) async {
    return await delete('/income/$id');
  }

  // Expense methods
  Future<List<dynamic>> getExpenses({String? month, String? goalId}) async {
    try {
      Map<String, String>? queryParams;
      if (month != null && goalId != null) {
        queryParams = {'month': month, 'goalId': goalId};
      } else if (month != null) {
        queryParams = {'month': month};
      } else if (goalId != null) {
        queryParams = {'goalId': goalId};
      }
      
      final jsonResponse = await get('/expenses', queryParams: queryParams);
      return jsonResponse;
    } catch (e) {
      print('Error fetching expenses: $e');
      throw Exception('Failed to load expenses: $e');
    }
  }

  Future<dynamic> addExpense(Map<String, dynamic> expenseData) async {
    return await post('/expenses', expenseData);
  }

  Future<dynamic> updateExpense(String id, Map<String, dynamic> expenseData) async {
    return await put('/expenses/$id', expenseData);
  }

  Future<dynamic> deleteExpense(String id) async {
    return await delete('/expenses/$id');
  }

  // Budget methods
  Future<List<dynamic>> getBudgets({String? month}) async {
    try {
      final Map<String, String>? queryParams = month != null ? {'month': month} : null;
      final jsonResponse = await get('/budgets', queryParams: queryParams);
      return jsonResponse;
    } catch (e) {
      print('Error fetching budgets: $e');
      throw Exception('Failed to load budgets: $e');
    }
  }

  // Add budget method
  Future<dynamic> addBudget(Map<String, dynamic> budgetData) async {
    try {
      return await post('/budgets', budgetData);
    } catch (e) {
      print('Error adding budget: $e');
      throw Exception('Failed to add budget: $e');
    }
  }

  // Update budget method
  Future<dynamic> updateBudget(String id, Map<String, dynamic> budgetData) async {
    try {
      return await put('/budgets/$id', budgetData);
    } catch (e) {
      print('Error updating budget: $e');
      throw Exception('Failed to update budget: $e');
    }
  }

  // Delete budget method
  Future<dynamic> deleteBudget(String id) async {
    try {
      return await delete('/budgets/$id');
    } catch (e) {
      print('Error deleting budget: $e');
      throw Exception('Failed to delete budget: $e');
    }
  }

  // Goals methods
  Future<List<dynamic>> getGoals() async {
    try {
      final jsonResponse = await get('/goals');
      return jsonResponse;
    } catch (e) {
      print('Error fetching goals: $e');
      throw Exception('Failed to load goals: $e');
    }
  }

  Future<List<dynamic>> getGoalDetails() async {
    try {
      final jsonResponse = await get('/goals/details');
      return jsonResponse;
    } catch (e) {
      print('Error fetching goal details: $e');
      throw Exception('Failed to load goal details: $e');
    }
  }

  Future<dynamic> addGoal(Map<String, dynamic> goalData) async {
    return await post('/goals', goalData);
  }

  Future<dynamic> updateGoal(String id, Map<String, dynamic> goalData) async {
    return await put('/goals/$id', goalData);
  }

  Future<dynamic> deleteGoal(String id) async {
    return await delete('/goals/$id');
  }

  // Alerts methods
  Future<Map<String, dynamic>> getAlerts({String? month}) async {
    try {
      final Map<String, String>? queryParams = month != null ? {'month': month} : null;
      final jsonResponse = await get('/alerts', queryParams: queryParams);
      return jsonResponse;
    } catch (e) {
      print('Error fetching alerts: $e');
      throw Exception('Failed to load alerts: $e');
    }
  }

  // Prediction methods
  Future<Map<String, dynamic>> getPrediction() async {
    try {
      final jsonResponse = await get('/prediction');
      return jsonResponse;
    } catch (e) {
      print('Error fetching prediction: $e');
      throw Exception('Failed to load prediction: $e');
    }
  }

  // Chat methods
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    return await post('/chat', {'message': message});
  }
}
