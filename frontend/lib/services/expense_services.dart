// lib/services/expense_service.dart
import 'dart:convert';
import 'http_service.dart';

class ExpenseService {
  final HttpService _httpService = HttpService();

  Future<List<Map<String, dynamic>>> fetchExpenseData() async {
    try {
      final response = await _httpService.get('/expenses');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch expense data');
      }
    } catch (e) {
      print('Error fetching expense data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await _httpService.post('/expenses', expenseData);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add expense');
      }
    } catch (e) {
      print('Error adding expense: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateExpense(String id, Map<String, dynamic> expenseData) async {
    try {
      final response = await _httpService.put('/expenses/$id', expenseData);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update expense');
      }
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final response = await _httpService.delete('/expenses/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete expense');
      }
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }
}