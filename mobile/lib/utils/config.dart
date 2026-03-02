import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  // Pour un téléphone réel, utilisez l'IP de votre PC
  // Vous pouvez changer cette IP dans l'écran de configuration
  // IP actuelle du PC: 192.168.0.2
  static const String defaultIp = '192.168.2.115';
  static const String defaultPort = '8000';

  // URL personnalisée (peut être changée via l'écran de config)
  static String _customUrl = '';
  static bool _hasCustomUrl = false;

  // Cette méthode calcule l'URL de base dynamiquement à chaque appel
  static String get baseUrl {
    // D'abord vérifier si une URL personnalisée est définie
    if (_hasCustomUrl && _customUrl.isNotEmpty) {
      return _customUrl;
    }
    // Sinon utiliser l'URL par défaut avec l'IP du PC
    return 'http://$defaultIp:$defaultPort';
  }

  // Méthode pour définir une URL personnalisée
  static void setCustomUrl(String url) {
    _customUrl = url;
    _hasCustomUrl = url.isNotEmpty;
  }

  // Méthode pour obtenir l'URL effective (alias pour baseUrl)
  static String get effectiveUrl => baseUrl;

  // Méthode pour construire l'URL avec une IP personnalisée
  static String getUrlWithIp(String ip, {String port = '8000'}) {
    return 'http://$ip:$port';
  }

  // Charger la configuration depuis SharedPreferences
  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setCustomUrl(savedUrl);
      }
    } catch (e) {
      // En cas d'erreur, utiliser les valeurs par défaut
    }
  }

  // Sauvegarder la configuration dans SharedPreferences
  static Future<void> saveConfig(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
    setCustomUrl(url);
  }
}
