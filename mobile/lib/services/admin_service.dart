import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';
import '../utils/cache_store.dart';

class AdminService {
  static String get _base => Config.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> getTechnicians() async {
    const key = 'admin_technicians';
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('$_base/api/admin/technicians'), headers: h)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(r.body)['technicians']);
        await CacheStore.set(key, list);
        return list;
      }
      if (r.statusCode == 401) throw Exception('Session expirée, veuillez vous reconnecter');
      throw Exception('Erreur ${r.statusCode}');
    } catch (e) {
      if (e.toString().contains('Session')) rethrow;
      final cached = await CacheStore.get<List>(key);
      if (cached != null) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
      rethrow;
    }
  }

  static Future<void> createTechnician(String username, String password) async {
    final h = await _headers();
    final r = await http.post(Uri.parse('$_base/api/admin/technicians'),
        headers: h, body: jsonEncode({'username': username, 'password': password}));
    if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['detail'] ?? 'Erreur');
  }

  static Future<void> deleteTechnician(int userId) async {
    final h = await _headers();
    final r = await http.delete(Uri.parse('$_base/api/admin/technicians/$userId'), headers: h);
    if (r.statusCode != 200) throw Exception('Erreur suppression');
  }

  static Future<void> updateUsername(int userId, String newUsername) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$_base/api/admin/technicians/$userId/username'),
        headers: h, body: jsonEncode({'new_username': newUsername}));
    if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['detail'] ?? 'Erreur');
  }

  static Future<void> updateOdooId(int userId, String newId) async {
    final h = await _headers();
    final r = await http.put(Uri.parse('$_base/api/admin/technicians/$userId/odoo-id'),
        headers: h, body: jsonEncode({'new_user_id': newId}));
    if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['detail'] ?? 'Erreur');
  }

  static Future<List<Map<String, dynamic>>> getTechnicianTasks(int userId) async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$_base/api/admin/technicians/$userId/tasks'), headers: h);
    if (r.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(r.body)['tasks']);
    }
    throw Exception('Erreur ${r.statusCode}');
  }

  /// Charge les tâches depuis l'API Odoo helpdesk.
  /// Filtre par assigned_to_id si fourni.
  static Future<List<Map<String, dynamic>>> getHelpdeskTasks({String? odooUserId}) async {
    final key = 'helpdesk_tasks_${odooUserId ?? 'all'}';
    const helpdeskUrl = 'http://41.226.24.13:5000/api/helpdesk/tasks';
    try {
      final r = await http
          .get(Uri.parse(helpdeskUrl))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final List<dynamic> all = jsonDecode(r.body);
        final tasks = all.map((j) => Map<String, dynamic>.from(j as Map)).toList();
        final filtered = (odooUserId != null && odooUserId.isNotEmpty)
            ? tasks.where((t) {
                final id = int.tryParse(odooUserId);
                final tid = t['assigned_to_id'];
                return tid != null && (tid == id || tid.toString() == odooUserId);
              }).toList()
            : tasks;
        await CacheStore.set(key, filtered);
        return filtered;
      }
    } catch (_) {}
    // Fallback cache
    final cached = await CacheStore.get<List>(key);
    if (cached != null) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    const key = 'admin_dashboard';
    try {
      final h = await _headers();
      final r = await http
          .get(Uri.parse('$_base/api/admin/dashboard'), headers: h)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        await CacheStore.set(key, data);
        return data;
      }
      throw Exception('Erreur ${r.statusCode}');
    } catch (e) {
      final cached = await CacheStore.get<Map>(key);
      if (cached != null) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getTechnicianPerformance(int userId) async {
    final key = 'perf_$userId';
    try {
      final h = await _headers();
      final r = await http
          .get(Uri.parse('$_base/api/admin/technicians/$userId/performance'), headers: h)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        await CacheStore.set(key, data);
        return data;
      }
      throw Exception('Erreur ${r.statusCode}');
    } catch (e) {
      final cached = await CacheStore.get<Map>(key);
      if (cached != null) return Map<String, dynamic>.from(cached);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getActivityFeed() async {
    const key = 'admin_activity_feed';
    try {
      final h = await _headers();
      final r = await http
          .get(Uri.parse('$_base/api/admin/activity-feed'), headers: h)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(r.body));
        await CacheStore.set(key, list);
        return list;
      }
      throw Exception('Erreur ${r.statusCode}');
    } catch (e) {
      final cached = await CacheStore.get<List>(key);
      if (cached != null) return cached.map((e) => Map<String, dynamic>.from(e)).toList();
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTask(int userId, Map<String, dynamic> task) async {
    final h = await _headers();
    final r = await http.post(Uri.parse('$_base/api/admin/technicians/$userId/tasks'),
        headers: h, body: jsonEncode(task));
    if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['detail'] ?? 'Erreur');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  static Future<void> deleteTask(int userId, int taskId) async {
    final h = await _headers();
    final r = await http.delete(
        Uri.parse('$_base/api/admin/technicians/$userId/tasks/$taskId'), headers: h);
    if (r.statusCode != 200) throw Exception('Erreur suppression tâche');
  }

  static Future<Map<String, dynamic>> getLiveInsights() async {
    const key = 'admin_live_insights';
    try {
      final h = await _headers();
      final r = await http
          .get(Uri.parse('$_base/api/admin/live-insights'), headers: h)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        await CacheStore.set(key, data);
        return data;
      }
      throw Exception('Erreur ${r.statusCode}');
    } catch (e) {
      final cached = await CacheStore.get<Map>(key);
      if (cached != null) return Map<String, dynamic>.from(cached);
      return {'anomalies': [], 'insights': [], 'recommendations': [], 'summary': {}};
    }
  }
}