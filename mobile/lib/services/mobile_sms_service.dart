import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';
import 'auth_service.dart';

class MobileSmsService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> sendSms(String to, String message) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/sms/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'to': to,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur envoi SMS: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getResponses() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/api/sms/responses'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['responses']);
      } else {
        throw Exception('Erreur: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur récupération réponses: $e');
    }
  }
}
