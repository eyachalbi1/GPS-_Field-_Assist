import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Opérateurs téléphoniques disponibles
enum MobileOperator {
  ooredoo,
  orange,
  telecom,
}

class Config {
  // Pour un téléphone réel, utilisez l'IP de votre PC
  // Vous pouvez changer cette IP dans l'écran de configuration
  static const String defaultIp = '192.168.43.24';
  static const String defaultPort = '8000';

  // URL personnalisée
  static String _customUrl = '';
  static bool _hasCustomUrl = false;

  // Opérateur sélectionné
  static MobileOperator _selectedOperator = MobileOperator.telecom;
  static bool _hasSelectedOperator = false;

  // Commandes APN par opérateur
  static const Map<MobileOperator, String> apnCommands = {
    MobileOperator.ooredoo: 'APN,m2m.tunav.com,tunav,tunav#',
    MobileOperator.orange: 'APN,apn.tunav.tn#',
    MobileOperator.telecom: 'APN,internet.tn#',
  };

  // Noms des opérateurs
  static const Map<MobileOperator, String> operatorNames = {
    MobileOperator.ooredoo: 'Ooredoo',
    MobileOperator.orange: 'Orange',
    MobileOperator.telecom: 'Telecom',
  };

  // Chemins des images des opérateurs
  static const Map<MobileOperator, String> operatorImages = {
    MobileOperator.ooredoo: 'assets/logo_ooredoo.png',
    MobileOperator.orange: 'assets/logo_orange.png',
    MobileOperator.telecom: 'assets/logo_telecom.png',
  };

  // Calcul dynamique de l'URL de base
  static String get baseUrl {
    if (_hasCustomUrl && _customUrl.isNotEmpty) {
      return _customUrl;
    }
    return 'http://$defaultIp:$defaultPort';
  }

  // Alias pour l'URL effective
  static String get effectiveUrl => baseUrl;

  // Définir une URL personnalisée
  static void setCustomUrl(String url) {
    _customUrl = url;
    _hasCustomUrl = url.isNotEmpty;
  }

  // Construire une URL avec une IP personnalisée
  static String getUrlWithIp(String ip, {String port = '8000'}) {
    return 'http://$ip:$port';
  }

  // Obtenir l'opérateur sélectionné
  static MobileOperator get selectedOperator => _selectedOperator;

  // Définir l'opérateur sélectionné
  static void setSelectedOperator(MobileOperator operator) {
    _selectedOperator = operator;
    _hasSelectedOperator = true;
  }

  // Obtenir la commande APN actuelle
  static String get currentApnCommand =>
      apnCommands[_selectedOperator] ?? '';

  // Charger la configuration depuis SharedPreferences
  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Essayer de charger l'URL du serveur (nouveau format: URL complète)
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        setCustomUrl(savedUrl);
      } else {
        // Ancien format: charger server_ip et server_port séparément
        final savedIp = prefs.getString('server_ip');
        final savedPort = prefs.getString('server_port') ?? '8000';
        
        if (savedIp != null && savedIp.isNotEmpty) {
          setCustomUrl('http://$savedIp:$savedPort');
        }
      }

      // Charger l'opérateur sélectionné
      final savedOperator = prefs.getString('selected_operator');
      if (savedOperator != null && savedOperator.isNotEmpty) {
        try {
          _selectedOperator = MobileOperator.values.firstWhere(
            (op) => op.name == savedOperator,
            orElse: () => MobileOperator.telecom,
          );
          _hasSelectedOperator = true;
        } catch (e) {
          debugPrint("Erreur chargement opérateur: $e");
        }
      }
    } catch (e) {
      debugPrint("Erreur chargement configuration: $e");
    }
  }

  // Sauvegarder la configuration
  static Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_hasCustomUrl) {
        await prefs.setString('server_url', _customUrl);
      }

      if (_hasSelectedOperator) {
        await prefs.setString(
          'selected_operator',
          _selectedOperator.name,
        );
      }
    } catch (e) {
      debugPrint("Erreur sauvegarde configuration: $e");
    }
  }

  // Réinitialiser la configuration
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
      debugPrint("Erreur reset configuration: $e");
    }
  }
}
