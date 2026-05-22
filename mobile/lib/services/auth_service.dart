import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static String get _baseUrl => '${Config.baseUrl}/api/auth';
  static const int _maxRetries = 3;
  static const int _retryDelayMs = 1500;

  Future<bool> login(String username, String password) async {
    String? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/login'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'username': username, 'password': password}),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, data['token']);
          await prefs.setString(_userKey, json.encode(data['user']));
          // Sauvegarder assigned_to_id séparément pour accès rapide
          final odooId = data['user']['assigned_to_id']?.toString() ?? '';
          await prefs.setString('odoo_id', odooId);
          return true;
        }

        if (response.statusCode == 401) {
          throw Exception('Nom d\'utilisateur ou mot de passe incorrect');
        }

        final detail = response.body.isNotEmpty
            ? response.body
            : 'status ${response.statusCode}';
        throw Exception('Echec login API (${response.statusCode}): $detail');
      } on TimeoutException {
        lastError = 'Timeout: serveur injoignable (${Config.baseUrl})';
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: _retryDelayMs * attempt));
        }
      } on SocketException {
        lastError = 'Reseau: impossible de joindre ${Config.baseUrl}';
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: _retryDelayMs * attempt));
        }
      } catch (e) {
        if (e.toString().contains('incorrect') ||
            e.toString().contains('401')) {
          rethrow;
        }
        lastError = 'Erreur de connexion API: $e';
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: _retryDelayMs * attempt));
        }
      }
    }

    throw Exception(
        'Connexion échouée après $_maxRetries tentatives. $lastError');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    final data = json.decode(raw);
    return data['role'] as String?;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    final data = json.decode(raw);
    return data['username'] as String?;
  }

  Future<String?> getOdooId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('odoo_id');
    return (v != null && v.isNotEmpty) ? v : null;
  }
}
