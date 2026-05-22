import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/config.dart';
import '../utils/cache_store.dart';
import 'auth_service.dart';

class TaskService {
  static const String _helpdeskUrl    = 'http://41.226.24.13:5000/api/helpdesk/tasks';
  static const String _helpdeskUpdate = 'http://41.226.24.13:5000/api/helpdesk/update-stage';
  static String get _baseUrl => '${Config.effectiveUrl}/api/tasks';

  // Mapping statut Flutter → stage Odoo
  static const Map<String, int> _stageMap = {
    'nouveau':  1,
    'en_cours': 2,
    'termine':  4,
    'annule':   5,
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

  static const _cacheKeyTasks = 'tasks_list';

  Future<List<Task>> getTasks() async {
    final odooId = await AuthService().getOdooId();

    List<dynamic>? rawData;

    // 1. API Odoo helpdesk
    try {
      final response = await http
          .get(Uri.parse(_helpdeskUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> all = json.decode(response.body);
        // Filtrer par assigned_to_id si disponible
        rawData = odooId != null
            ? all.where((t) => t['assigned_to_id']?.toString() == odooId).toList()
            : all;
        await CacheStore.set(_cacheKeyTasks, rawData);
        return rawData.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Helpdesk API error: $e');
    }

    // 2. Fallback API locale
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(_baseUrl), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await CacheStore.set(_cacheKeyTasks, data);
        return data.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Local API error: $e');
    }

    // 3. Cache
    final cached = await CacheStore.get<List>(_cacheKeyTasks);
    if (cached != null) {
      debugPrint('TaskService: using cached tasks');
      return cached.map((j) => Task.fromJson(Map<String, dynamic>.from(j))).toList();
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

  /// [stageKey] : 'nouveau' | 'en_cours' | 'termine' | 'annule'
  Future<bool> updateStage(String taskId, String stageKey) async {
    final stageId = _stageMap[stageKey];
    if (stageId == null) return false;
    try {
      // API uses GET /api/helpdesk/update-stage/{ticketId}/{stageId}
      final res = await http
          .get(Uri.parse('$_helpdeskUpdate/$taskId/$stageId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return true;
      debugPrint('updateStage HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('updateStage error: $e');
    }
    return false;
  }

  Future<void> deleteTaskMedia(String taskId, String filename) async {
    final uri = Uri.parse(
        '${Config.effectiveUrl}/api/files/task/$taskId/media/$filename');
    await http.delete(uri);
  }
}
