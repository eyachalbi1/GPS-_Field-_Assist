import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

// Available mobile operators
enum MobileOperator {
  ooredoo,
  orange,
  telecom,
}

class Config {
  // Login server (PC local)
  static const String defaultIp = '192.168.43.90';
  static const String defaultPort = '8000';

  // API server (serveur externe)
  static const String defaultApiIp = '41.226.24.13';
  static const String defaultApiPort = '5000';

  // Custom URL state (login server port 8000)
  static String _customUrl = '';
  static bool _hasCustomUrl = false;

  // Custom API IP (port 5000) — séparé du login
  static String _customApiIp = '';

  // Selected operator state
  static MobileOperator _selectedOperator = MobileOperator.telecom;
  static bool _hasSelectedOperator = false;

  // APN commands per operator
  static const Map<MobileOperator, String> apnCommands = {
    MobileOperator.ooredoo: 'APN,m2m.tunav.com,tunav,tunav#',
    MobileOperator.orange: 'APN,apn.tunav.tn#',
    MobileOperator.telecom: 'APN,internet.tn#',
  };

  // Operator display names
  static const Map<MobileOperator, String> operatorNames = {
    MobileOperator.ooredoo: 'Ooredoo',
    MobileOperator.orange: 'Orange',
    MobileOperator.telecom: 'Telecom',
  };

  // Operator logos
  static const Map<MobileOperator, String> operatorImages = {
    MobileOperator.ooredoo: 'assets/logo_ooredoo.png',
    MobileOperator.orange: 'assets/logo_orange.png',
    MobileOperator.telecom: 'assets/logo_telecom.png',
  };

  // Login server URL (PC local, port 8000)
  static String get baseUrl {
    if (_hasCustomUrl && _customUrl.isNotEmpty) return _customUrl;
    return 'http://$defaultIp:$defaultPort';
  }

  // API base URL (même IP, port 5000)
  static String get apiBaseUrl {
    final ip = _customApiIp.isNotEmpty ? _customApiIp : defaultApiIp;
    return 'http://$ip:$defaultApiPort';
  }

  // Alias for effective URL
  static String get effectiveUrl => baseUrl;

  // Set custom URL (login server)
  static void setCustomUrl(String url) {
    _customUrl = url;
    _hasCustomUrl = url.isNotEmpty;
    // Extraire l'IP pour apiBaseUrl
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      _customApiIp = uri.host;
    }
  }

  // Build URL with a custom IP
  static String getUrlWithIp(String ip, {String port = '8000'}) {
    return 'http://$ip:$port';
  }

  // Get selected operator
  static MobileOperator get selectedOperator => _selectedOperator;

  // Set selected operator
  static void setSelectedOperator(MobileOperator operator) {
    _selectedOperator = operator;
    _hasSelectedOperator = true;
  }

  // Get current APN command
  static String get currentApnCommand {
    return apnCommands[_selectedOperator] ?? '';
  }

  // Expose whether an operator was explicitly selected
  static bool get hasSelectedOperator => _hasSelectedOperator;

  // Load configuration from SharedPreferences
  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load server URL
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setCustomUrl(savedUrl);
      }
      // Load API IP séparé si présent
      final savedApiIp = prefs.getString('api_ip');
      if (savedApiIp != null && savedApiIp.isNotEmpty) {
        _customApiIp = savedApiIp;
      }

      // Load selected operator
      final savedOperator = prefs.getString('selected_operator');
      if (savedOperator != null && savedOperator.isNotEmpty) {
        try {
          _selectedOperator = MobileOperator.values.firstWhere(
            (op) => op.name == savedOperator,
            orElse: () => MobileOperator.telecom,
          );
          _hasSelectedOperator = true;
        } catch (e) {
          developer.log('Error loading operator: $e');
        }
      }
    } catch (e) {
      developer.log('Error loading config: $e');
    }
  }

  // Save configuration
  static Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_hasCustomUrl) {
        await prefs.setString('server_url', _customUrl);
      }

      if (_hasSelectedOperator) {
        await prefs.setString('selected_operator', _selectedOperator.name);
      }
    } catch (e) {
      developer.log('Error saving config: $e');
    }
  }

  // Reset configuration
  static Future<void> resetConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('server_url');
      await prefs.remove('selected_operator');

      _customUrl = '';
      _hasCustomUrl = false;
      _selectedOperator = MobileOperator.telecom;
      _hasSelectedOperator = false;
    } catch (e) {
      developer.log('Error resetting config: $e');
    }
  }

  // Module command persistence helpers
  static String _moduleCommandsKey(String moduleName) {
    final safeName = moduleName.trim().replaceAll(' ', '_');
    return 'module_commands_$safeName';
  }

  static Future<Map<String, dynamic>?> loadModuleCommands(
    String moduleName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_moduleCommandsKey(moduleName));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      developer.log('Error loading module commands: $e');
      return null;
    }
  }

  static Future<void> saveModuleCommands(
    String moduleName,
    List<Map<String, dynamic>> commands,
    int nextIndex,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'commands': commands,
        'nextIndex': nextIndex,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(
        _moduleCommandsKey(moduleName),
        jsonEncode(payload),
      );
    } catch (e) {
      developer.log('Error saving module commands: $e');
    }
  }

  static Future<void> clearModuleCommands(String moduleName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_moduleCommandsKey(moduleName));
    } catch (e) {
      developer.log('Error clearing module commands: $e');
    }
  }
}
