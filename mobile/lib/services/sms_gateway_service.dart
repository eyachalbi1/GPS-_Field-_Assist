import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/config.dart';
import 'auth_service.dart';

class SmsGatewayService {
  SmsGatewayService._();

  static final AuthService _authService = AuthService();

  static Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static List<String> get _gatewayBases => [
        '${Config.baseUrl}/api/sms/gateway',
        '${Config.baseUrl}/api/sms-gateway',
      ];

  static Future<Map<String, dynamic>> sendSmsCommand({
    required String phone,
    required String message,
    String? moduleName,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Non authentifie',
      };
    }

    final payload = {
      'phone': phone,
      'to': phone,
      'message': message,
      if (moduleName != null && moduleName.isNotEmpty) 'module_name': moduleName,
      if (moduleName != null && moduleName.isNotEmpty) 'moduleName': moduleName,
    };

    for (final base in _gatewayBases) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/queue'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = _decodeJson(response.body);
          final smsId = data['sms_id'] ?? data['id'];
          return {
            'success': true,
            'sms_id': smsId,
            'message': data['message'] ?? 'SMS enfile',
          };
        }
      } catch (_) {}

      try {
        final response = await http
            .post(
              Uri.parse('$base/send'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = _decodeJson(response.body);
          final smsId = data['sms_id'] ?? data['id'];
          return {
            'success': true,
            'sms_id': smsId,
            'message': data['message'] ?? 'SMS cree',
          };
        }
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Impossible d\'envoyer la commande au serveur gateway',
    };
  }

  static Future<Map<String, dynamic>?> getSmsStatus(int smsId) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    for (final base in _gatewayBases) {
      try {
        final response = await http
            .get(
              Uri.parse('$base/$smsId'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = _decodeJson(response.body);
          if (data.containsKey('sms')) {
            return Map<String, dynamic>.from(data['sms'] as Map);
          }
          return data;
        }
      } catch (_) {}

      try {
        final response = await http
            .get(
              Uri.parse('$base/status/$smsId'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = _decodeJson(response.body);
          if (data.containsKey('sms')) {
            return Map<String, dynamic>.from(data['sms'] as Map);
          }
          return data;
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getPendingSms() async {
    final token = await _authService.getToken();
    if (token == null) return const [];

    for (final base in _gatewayBases) {
      try {
        final response = await http
            .get(
              Uri.parse('$base/pending'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = _decodeJson(response.body);
          if (data['pending'] is List) {
            return List<Map<String, dynamic>>.from(data['pending'] as List);
          }
          if (data['sms'] is List) {
            return List<Map<String, dynamic>>.from(data['sms'] as List);
          }
          if (data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data'] as List);
          }
          return const [];
        }
      } catch (_) {}
    }

    return const [];
  }

  static Future<bool> markSmsSent(int smsId) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final payload = {
      'status': 'sent',
      'sent_at': DateTime.now().toIso8601String(),
    };

    for (final base in _gatewayBases) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/$smsId/sent'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {}

      try {
        final response = await http
            .put(
              Uri.parse('$base/$smsId'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  static Future<bool> saveResponse(int smsId, String responseText) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final payload = {
      'response': responseText,
      'status': 'completed',
      'received_at': DateTime.now().toIso8601String(),
    };

    for (final base in _gatewayBases) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/$smsId/response'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {}

      try {
        final response = await http
            .put(
              Uri.parse('$base/$smsId'),
              headers: _headers(token),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  static Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }
}
