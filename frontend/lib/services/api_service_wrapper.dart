import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class ApiServiceWrapper {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Helper method to get the base URL based on platform
  String get baseUrl => _apiService.baseUrl;

  // Helper method to get auth token
  Future<String?> getAuthToken({bool forceRefresh = false}) async {
    return await _apiService.getAuthToken(forceRefresh: forceRefresh);
  }

  // Test connection to verify API is reachable
  Future<bool> testConnection() async {
    return await _apiService.testConnection();
  }

  // User methods
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      return await _apiService.getUserProfile();
    } catch (e) {
      print('Error in getUserProfile: $e');
      rethrow;
    }
  }

  // Income methods
  Future<List<dynamic>> getIncome({String? month}) async {
    try {
      return await _apiService.getIncome(month: month);
    } catch (e) {
      print('Error in getIncome: $e');
      rethrow;
    }
  }

  Future<dynamic> addIncome(Map<String, dynamic> incomeData) async {
    try {
      return await _apiService.addIncome(incomeData);
    } catch (e) {
      print('Error in addIncome: $e');
      rethrow;
    }
  }

  Future<dynamic> updateIncome(String id, Map<String, dynamic> incomeData) async {
    try {
      return await _apiService.updateIncome(id, incomeData);
    } catch (e) {
      print('Error in updateIncome: $e');
      rethrow;
    }
  }

  Future<dynamic> deleteIncome(String id) async {
    try {
      return await _apiService.deleteIncome(id);
    } catch (e) {
      print('Error in deleteIncome: $e');
      rethrow;
    }
  }

  // Expense methods
  Future<List<dynamic>> getExpenses({String? month, String? goalId}) async {
    try {
      return await _apiService.getExpenses(month: month, goalId: goalId);
    } catch (e) {
      print('Error in getExpenses: $e');
      rethrow;
    }
  }
  // Add this method to get expenses by goal ID
  Future<List<dynamic>?> getExpensesByGoalId(String goalId) async {
    try {
      return await _apiService.getExpenses(goalId: goalId);
    } catch (e) {
      print('Error in getExpensesByGoalId: $e');
      return null;
    }
  }

  Future<dynamic> addExpense(Map<String, dynamic> expenseData) async {
    try {
      return await _apiService.addExpense(expenseData);
    } catch (e) {
      print('Error in addExpense: $e');
      rethrow;
    }
  }

  Future<dynamic> updateExpense(String id, Map<String, dynamic> expenseData) async {
    try {
      return await _apiService.updateExpense(id, expenseData);
    } catch (e) {
      print('Error in updateExpense: $e');
      rethrow;
    }
  }

  Future<dynamic> deleteExpense(String id) async {
    try {
      return await _apiService.deleteExpense(id);
    } catch (e) {
      print('Error in deleteExpense: $e');
      rethrow;
    }
  }

  // Budget methods
  Future<List<dynamic>> getBudgets({String? month}) async {
    try {
      return await _apiService.getBudgets(month: month);
    } catch (e) {
      print('Error in getBudgets: $e');
      rethrow;
    }
  }

  // Add budget method
  Future<dynamic> addBudget(Map<String, dynamic> budgetData) async {
    try {
      return await _apiService.addBudget(budgetData);
    } catch (e) {
      print('Error in addBudget: $e');
      rethrow;
    }
  }

  // Update budget method
  Future<dynamic> updateBudget(String id, Map<String, dynamic> budgetData) async {
    try {
      return await _apiService.updateBudget(id, budgetData);
    } catch (e) {
      print('Error in updateBudget: $e');
      rethrow;
    }
  }

  // Delete budget method
  Future<bool> deleteBudget(String id) async {
    try {
      await _apiService.deleteBudget(id);
      return true;
    } catch (e) {
      print('Error in deleteBudget: $e');
      return false;
    }
  }

  // Goals methods
  Future<List<dynamic>> getGoals() async {
    try {
      return await _apiService.getGoals();
    } catch (e) {
      print('Error in getGoals: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getGoalDetails() async {
    try {
      return await _apiService.getGoalDetails();
    } catch (e) {
      print('Error in getGoalDetails: $e');
      rethrow;
    }
  }

  // Add this method to create a goal
  Future<bool> createGoal(Map<String, dynamic> goalData) async {
    try {
      await _apiService.addGoal(goalData);
      return true;
    } catch (e) {
      print('Error in createGoal: $e');
      return false;
    }
  }
  

  Future<dynamic> addGoal(Map<String, dynamic> goalData) async {
    try {
      return await _apiService.addGoal(goalData);
    } catch (e) {
      print('Error in addGoal: $e');
      rethrow;
    }
  }

  Future<bool> updateGoal(String id, Map<String, dynamic> goalData) async {
    try {
      var response = await _apiService.updateGoal(id, goalData);
      // Return true if the request was successful
      return true;
    } catch (e) {
      print('Error in updateGoal: $e');
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      var response = await _apiService.deleteGoal(id);
      // Return true if the request was successful
      return true;
    } catch (e) {
      print('Error in deleteGoal: $e');
      return false;
    }
  }

  // Alerts methods
  Future<Map<String, dynamic>> getAlerts({String? month}) async {
    try {
      return await _apiService.getAlerts(month: month);
    } catch (e) {
      print('Error in getAlerts: $e');
      rethrow;
    }
  }

  // Prediction methods
  Future<Map<String, dynamic>> getPrediction() async {
    try {
      return await _apiService.getPrediction();
    } catch (e) {
      print('Error in getPrediction: $e');
      rethrow;
    }
  }

  // Chat methods
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    try {
      return await _apiService.sendChatMessage(message);
    } catch (e) {
      print('Error in sendChatMessage: $e');
      rethrow;
    }
  }
}
