import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value cache backed by SharedPreferences.
/// Stores any JSON-serialisable value with an optional TTL.
class CacheStore {
  static const _prefix = 'cache_';

  /// Save [value] under [key]. [ttlMinutes] = 0 means no expiry.
  static Future<void> set(String key, dynamic value, {int ttlMinutes = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'data': value,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttlMinutes,
    };
    await prefs.setString('$_prefix$key', jsonEncode(payload));
  }

  /// Returns the cached value or null if missing / expired.
  static Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final ttl = payload['ttl'] as int;
      if (ttl > 0) {
        final age = DateTime.now().millisecondsSinceEpoch - (payload['ts'] as int);
        if (age > ttl * 60 * 1000) return null; // expired
      }
      return payload['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
