// lib/services/income_service.dart
import 'dart:convert';
import 'http_service.dart';

class IncomeService {
  final HttpService _httpService = HttpService();

  Future<List<Map<String, dynamic>>> fetchIncomeData() async {
    try {
      final response = await _httpService.get('/income');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch income data');
      }
    } catch (e) {
      print('Error fetching income data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addIncome(Map<String, dynamic> incomeData) async {
    try {
      final response = await _httpService.post('/income', incomeData);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add income');
      }
    } catch (e) {
      print('Error adding income: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateIncome(String id, Map<String, dynamic> incomeData) async {
    try {
      final response = await _httpService.put('/income/$id', incomeData);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update income');
      }
    } catch (e) {
      print('Error updating income: $e');
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    try {
      final response = await _httpService.delete('/income/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete income');
      }
    } catch (e) {
      print('Error deleting income: $e');
      rethrow;
    }
  }
}