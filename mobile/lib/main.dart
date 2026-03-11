import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'utils/config.dart';
import 'services/gps_device_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger la configuration du serveur au démarrage
  // Utiliser Config.loadConfig() qui charge correctement server_url
  await Config.loadConfig();
  // Start background refresh of GPS devices so app data stays in sync
  GpsDeviceService.startAutoRefresh();

  runApp(const MyApp());
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
