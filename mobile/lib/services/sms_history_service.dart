import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_history.dart';

class SmsHistoryService {
  static const String _storageKey = 'sms_history';

  static Future<List<SmsHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_storageKey);
    
    if (historyJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(historyJson);
    return decoded.map((json) => SmsHistoryItem.fromJson(json)).toList();
  }

  static Future<void> addToHistory(SmsHistoryItem item) async {
    final history = await getHistory();
    history.insert(0, item);
    
    // Garder seulement les 100 derniers
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }
    
    await _saveHistory(history);
  }

  static Future<void> updateStatus(String id, SmsHistoryStatus status, {String? response}) async {
    final history = await getHistory();
    final index = history.indexWhere((item) => item.id == id);
    
    if (index != -1) {
      history[index] = SmsHistoryItem(
        id: history[index].id,
        phone: history[index].phone,
        command: history[index].command,
        response: response ?? history[index].response,
        timestamp: history[index].timestamp,
        status: status,
        moduleName: history[index].moduleName,
      );
      await _saveHistory(history);
    }
  }

  static Future<void> _saveHistory(List<SmsHistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
