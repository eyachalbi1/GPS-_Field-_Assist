import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class AiDiagnosticService {
  static String get _base => Config.baseUrl;

  static Future<Map<String, dynamic>?> getRecommendations({
    String equipmentType = '',
    String symptom = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/ai/recommendations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'equipment_type': equipmentType, 'symptom': symptom}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('AiDiagnosticService.recommendations error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getTaskRecommendations({
    String name = '',
    String description = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/ai/task-recommendations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'description': description}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('AiDiagnosticService.taskRecommendations error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPredictiveAlerts() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/api/ai/predictive'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('AiDiagnosticService.predictive error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getTaskPredictions(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/tasks/workload-prediction'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('AiDiagnosticService.getTaskPredictions error: $e');
    }
    return null;
  }
}
