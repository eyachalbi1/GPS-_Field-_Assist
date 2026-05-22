import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/config.dart';
import 'utils/app_theme.dart';
import 'services/gps_device_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Barre de statut transparente pour un rendu immersif
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Config.loadConfig();
  GpsDeviceService.startAutoRefresh();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static MyApp of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<MyApp>()!;

  bool get isDark => false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunav GPS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Wrapper global : chaque page a le dégradé en fond
      builder: (context, child) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: child!,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}


