import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger la configuration du serveur au démarrage
  await loadServerConfig();

  runApp(const MyApp());
}

Future<void> loadServerConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    final savedPort = prefs.getString('server_port') ?? '8000';

    if (savedIp != null && savedIp.isNotEmpty) {
      Config.setCustomUrl('http://$savedIp:$savedPort');
    }
  } catch (e) {
    // Utiliser la config par défaut en cas d'erreur
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunav GPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0066FF)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
