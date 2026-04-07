import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class DiagnosticConnectionScreen extends StatefulWidget {
  const DiagnosticConnectionScreen({super.key});

  @override
  State<DiagnosticConnectionScreen> createState() =>
      _DiagnosticConnectionScreenState();
}

class _DiagnosticConnectionScreenState
    extends State<DiagnosticConnectionScreen> {
  bool _isTesting = false;
  String _testResults = '';
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '5000');

  @override
  void initState() {
    super.initState();
    // Extraire l'IP de la config actuelle
    final currentIp =
        Config.effectiveUrl.replaceAll('http://', '').split(':')[0];
    _ipController.text = currentIp;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResults = '';
    });

    StringBuffer results = StringBuffer();
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final baseUrl = 'http://$ip:$port';

    results.writeln('🔍 Test de connexion');
    results.writeln('========================');
    results.writeln('URL de base: $baseUrl');
    results.writeln('');

    // Test 1: Ping du serveur
    results.write('1️⃣ Test serveur... ');
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/auth/users'))
          .timeout(const Duration(seconds: 10));
      results.writeln('✅ OK (Status: ${response.statusCode})');
    } catch (e) {
      results.writeln('❌ ÉCHEC: $e');
    }

    // Test 2: Test login
    results.write('2️⃣ Test login... ');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': 'tech1', 'password': 'tech123'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        results.writeln('✅ OK - Connexion réussie!');
        final data = json.decode(response.body);
        results.writeln('   Utilisateur: ${data['user']['username']}');
      } else if (response.statusCode == 401) {
        results.writeln('⚠️ Serveur accessible, mais identifiants incorrects');
      } else {
        results.writeln('⚠️ Status: ${response.statusCode}');
      }
    } catch (e) {
      results.writeln('❌ ÉCHEC: $e');
    }

    // Test 3: Vérifier la base de données
    results.write('3️⃣ Test base de données... ');
    results.writeln('(Via le serveur)');

    results.writeln('');
    results.writeln('========================');
    results.writeln('💡 Conseils:');
    results.writeln('- Vérifiez que le serveur est démarré');
    results.writeln('- Vérifiez que le mobile est sur le même WiFi');
    results.writeln('- Vérifiez l\'adresse IP du PC: $ip');

    setState(() {
      _testResults = results.toString();
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Connexion'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.c1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: AppTheme.cardBlue(radius: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚙️ Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.c1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'Adresse IP du serveur',
                              border: OutlineInputBorder(),
                              hintText: '192.168.x.x',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppTheme.c1,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isTesting
                            ? 'Test en cours...'
                            : 'Tester la connexion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.skyBottom,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_testResults.isNotEmpty)
            Container(
              decoration: AppTheme.cardBlue(radius: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _testResults,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppTheme.c1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.cardBlue(radius: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.c1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstruction('1.', 'Démarrez le serveur sur le PC:',
                        'backend/start_server.bat'),
                    _buildInstruction('2.', 'Notez l\'adresse IP du PC:',
                        'Tapez "ipconfig" dans cmd'),
                    _buildInstruction('3.', 'Vérifiez le pare-feu:',
                        'Autorisez Python dans le pare-feu'),
                    _buildInstruction(
                        '4.', 'Mobile et PC sur le même WiFi', ''),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0066FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



