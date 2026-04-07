import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class AiService {
  static String get _aiBase => Config.baseUrl;

  static Future<Map<String, dynamic>?> ask(String question) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_aiBase/api/ai/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question, 'top_k': 5}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('AiService.ask error: $e');
    }
    return null;
  }

  static Future<bool> reindex() async {
    try {
      final response = await http
          .post(Uri.parse('$_aiBase/api/ai/index'))
          .timeout(const Duration(seconds: 60));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AiService.reindex error: $e');
      return false;
    }
  }
}
