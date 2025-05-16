// lib/services/goal_service.dart
import 'dart:convert';
import 'http_service.dart';

class GoalService {
  final HttpService _httpService = HttpService();

  Future<List<Map<String, dynamic>>> fetchGoalData() async {
    try {
      final response = await _httpService.get('/goals');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch goal data');
      }
    } catch (e) {
      print('Error fetching goal data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addGoal(Map<String, dynamic> goalData) async {
    try {
      final response = await _httpService.post('/goals', goalData);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add goal');
      }
    } catch (e) {
      print('Error adding goal: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateGoal(String id, Map<String, dynamic> goalData) async {
    try {
      final response = await _httpService.put('/goals/$id', goalData);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update goal');
      }
    } catch (e) {
      print('Error updating goal: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      final response = await _httpService.delete('/goals/$id');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete goal');
      }
    } catch (e) {
      print('Error deleting goal: $e');
      rethrow;
    }
  }
}