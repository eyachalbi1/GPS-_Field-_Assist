import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/config.dart';

class TaskService {
  static const String _helpdeskUrl    = 'http://41.226.24.13:5000/api/helpdesk/tasks';
  static const String _helpdeskUpdate = 'http://41.226.24.10:5000/api/helpdesk/update-stage';
  static String get _baseUrl => '${Config.effectiveUrl}/api/tasks';

  // Mapping statut Flutter → stage Odoo
  static const Map<String, int> _stageMap = {
    'a_faire':  1, // Nouveau
    'en_cours': 2, // En cours
    'termine':  4, // Terminé
    'annule':   5, // Annulé
  };

  // Mapping stage Odoo → label
  static const Map<int, String> stageLabels = {
    1: 'Nouveau',
    2: 'En cours',
    4: 'Terminé',
    5: 'Annulé',
  };

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Task>> getTasks() async {
    // Essayer d'abord l'API helpdesk distante
    try {
      final response = await http
          .get(Uri.parse(_helpdeskUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Helpdesk API error: $e');
    }

    // Fallback : API locale
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(_baseUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Local API error: $e');
    }

    throw Exception('Impossible de charger les tâches');
  }

  Future<List<String>> getTaskMedia(String taskId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${Config.effectiveUrl}/api/files/task/$taskId/media'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> uploadFiles(String taskId, List<dynamic> files) async {
    return [];
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final statusString = status == TaskStatus.completed
        ? 'termine'
        : status == TaskStatus.inProgress
            ? 'en_cours'
            : 'a_faire';
    await updateStage(taskId, statusString);
  }

  /// Met à jour le stage via l'API Odoo helpdesk.
  /// [stageKey] : 'a_faire' | 'en_cours' | 'termine' | 'annule'
  Future<bool> updateStage(String taskId, String stageKey) async {
    final stageId = _stageMap[stageKey];
    if (stageId == null) return false;
    // Appel API Odoo
    try {
      final res = await http
          .put(Uri.parse('$_helpdeskUpdate/$taskId/$stageId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return true;
    } catch (e) {
      debugPrint('updateStage Odoo error: $e');
    }
    // Fallback API locale
    try {
      final headers = await _getHeaders();
      await http
          .put(
            Uri.parse('$_baseUrl/$taskId/status'),
            headers: headers,
            body: json.encode({'status': stageKey}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('updateStage local error: $e');
    }
    return false;
  }

  Future<void> deleteTaskMedia(String taskId, String filename) async {
    final uri = Uri.parse(
        '${Config.effectiveUrl}/api/files/task/$taskId/media/$filename');
    await http.delete(uri);
  }
}
