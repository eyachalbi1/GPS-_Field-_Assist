import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/config.dart';

class TaskService {
  static String get _baseUrl => '${Config.effectiveUrl}/api/tasks';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Task>> getTasks() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(_baseUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Non autorise - reconnectez-vous');
      }

      final body = response.body.isNotEmpty ? response.body : 'reponse vide';
      throw Exception(
          'Erreur API ${response.statusCode} sur $_baseUrl. Detail: $body');
    } catch (e) {
      throw Exception('Erreur de connexion API ($_baseUrl): $e');
    }
  }

  Future<List<String>> getTaskMedia(String taskId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('${Config.effectiveUrl}/api/files/task/$taskId/media'),
              headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> uploadFiles(String taskId, List<dynamic> files) async {
    return [];
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      final headers = await _getHeaders();
      final statusString = status == TaskStatus.completed
          ? 'termine'
          : status == TaskStatus.inProgress
              ? 'en_cours'
              : 'a_faire';

      final response = await http
          .put(
            Uri.parse('$_baseUrl/$taskId/status'),
            headers: headers,
            body: json.encode({'status': statusString}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = response.body.isNotEmpty ? response.body : 'reponse vide';
        throw Exception('Erreur mise a jour ${response.statusCode}: $body');
      }
    } catch (e) {
      throw Exception('Erreur de connexion API ($_baseUrl): $e');
    }
  }

  Future<void> deleteTaskMedia(String taskId, String filename) async {
    final uri = Uri.parse(
        '${Config.effectiveUrl}/api/files/task/$taskId/media/$filename');
    final res = await http.delete(uri);
    if (res.statusCode != 200) {
      throw Exception('Delete failed: ${res.statusCode}');
    }
  }
}
