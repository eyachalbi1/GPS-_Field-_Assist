import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import '../utils/config.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _ipController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  bool _isSendingConfig = false;
  String _currentIp = '';
  MobileOperator _selectedOperator = MobileOperator.telecom;
  bool _operatorConfirmed = false;
  final Telephony _telephony = Telephony.instance;
  
  // Liste des commandes de configuration SMS
  static const List<String> _configCommands = [
    'PROTOCOL,3,1#',
    'IP,41.226.27.169,85,1#',
    'IP2,41.226.27.169,85,1#',
    'HC,60,7200,7200#',
    'CORNER,20#',
    'UTC,0#',
    'SLEEP,0#',
    'LINE,4,1#',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip') ?? '';

    // Charger l'opérateur sélectionné
    final savedOperator = prefs.getString('selected_operator');
    if (savedOperator != null && savedOperator.isNotEmpty) {
      try {
        _selectedOperator = MobileOperator.values.firstWhere(
          (op) => op.name == savedOperator,
        );
      } catch (_) {
        _selectedOperator = MobileOperator.telecom;
      }
    }

    setState(() {
      _currentIp = savedIp.isNotEmpty ? savedIp : _getDefaultIp();
      _ipController.text = _currentIp;
      _operatorConfirmed = savedOperator != null && savedOperator.isNotEmpty;
    });
  }

  String _getDefaultIp() {
    // Extraire l'IP par défaut de Config
    return Config.defaultIp;
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<bool> _sendSmsOptimistic({
    required String phone,
    required String message,
  }) async {
    try {
      final hasPermission = await _telephony.requestSmsPermissions;
      if (hasPermission != true) {
        return false;
      }

      final completer = Completer<bool>();
      final fallbackTimer = Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      await _telephony.sendSms(
        to: phone,
        message: message,
        statusListener: (status) {
          if (status == SendStatus.SENT || status == SendStatus.DELIVERED) {
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        },
      );

      final result = await completer.future;
      fallbackTimer.cancel();
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendConfigSmsCommands() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un numero de telephone du module GPS'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSendingConfig = true);

    int successCount = 0;
    int failCount = 0;

    // Envoyer chaque commande séquentiellement (uniquement si opérateur confirmé)
    if (!_operatorConfirmed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner et confirmer un opérateur avant d envoyer les commandes.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isSendingConfig = false);
      return;
    }

    for (int i = 0; i < _configCommands.length; i++) {
      final command = _configCommands[i];
      bool commandSuccess = false;

      for (int attempt = 1; attempt <= 2; attempt++) {
        // Envoyer la commande SMS (succès optimiste si pas de statut)
        commandSuccess = await _sendSmsOptimistic(
          phone: phone,
          message: command,
        );

        if (commandSuccess) {
          successCount++;
          break;
        }

        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('le message n est pas envoyé  refait l opération'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        if (attempt == 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        failCount++;
        break;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;

    setState(() => _isSendingConfig = false);

    // Afficher le résultat final
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuration envoyee avec succes! ($successCount/$successCount commandes)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuration terminee avec erreurs: $successCount OK, $failCount echouees'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final ip = _ipController.text.trim();
    
    // Sauvegarder les valeurs séparées (pour compatibilité)
    await prefs.setString('server_ip', ip);
    await prefs.setString('selected_operator', _selectedOperator.name);
    
    // Sauvegarder l'URL login (port 8000) et l'IP API (port 5000)
    await prefs.setString('server_url', 'http://$ip:8000');
    await prefs.setString('api_ip', ip);

    // Mettre à jour la configuration statique
    Config.setCustomUrl('http://$ip:8000');
    Config.setSelectedOperator(_selectedOperator);

    setState(() => _isSaving = false);

    if (!mounted) return;

    // Demander si l'utilisateur veut envoyer les commandes de configuration
    if (_phoneController.text.isNotEmpty) {
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Envoyer la configuration SMS?'),
          content: Text(
            'Voulez-vous envoyer les commandes de configuration au module GPS?\n\n'
            'Opérateur: ${Config.operatorNames[_selectedOperator]}\n'
            'APN: ${Config.currentApnCommand}\n'
            'Telephone: ${_phoneController.text}\n\n'
            '${_configCommands.length} commandes seront envoyees sequentiellement.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.skyBottom,
                foregroundColor: Colors.white,
              ),
              child: const Text('Oui, envoyer'),
            ),
          ],
        ),
      );

      if (shouldSend == true) {
        await _sendConfigSmsCommands();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configuration sauvegardée! Opérateur: ${Config.operatorNames[_selectedOperator]}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildOperatorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.signal_cellular_alt, color: Color(0xFF0066FF)),
            SizedBox(width: 8),
            Text(
              'Opérateur téléphonique pour SMS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Sélectionnez l\'opérateur qui sera utilisé pour l\'envoi des commandes SMS:',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOperatorOption(
              operator: MobileOperator.telecom,
              name: 'Telecom',
              imagePath: 'assets/logo_telecom.png',
            ),
            _buildOperatorOption(
              operator: MobileOperator.orange,
              name: 'Orange',
              imagePath: 'assets/logo_orange.png',
            ),
            _buildOperatorOption(
              operator: MobileOperator.ooredoo,
              name: 'Ooredoo',
              imagePath: 'assets/logo_ooredoo.png',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Afficher l'opérateur sélectionné et son APN
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0066FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0066FF).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0066FF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'APN: ${Config.apnCommands[_selectedOperator]}',
                  style: const TextStyle(
                    color: Color(0xFF0066FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorOption({
    required MobileOperator operator,
    required String name,
    required String imagePath,
  }) {
    final isSelected = _selectedOperator == operator;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOperator = operator;
          _operatorConfirmed = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0066FF).withOpacity(0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0066FF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.signal_cellular_alt,
                    color: isSelected ? const Color(0xFF0066FF) : Colors.grey,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0066FF) : Colors.black87,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0066FF),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: AppTheme.skyLight),
                        SizedBox(width: 8),
                        Text(
                          'Adresse du serveur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse IP du PC',
                        hintText: '192.168.x.x',
                        helperText: 'Login: port 8000  |  API GPS: port 5000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telephone du module GPS',
                        hintText: '+21622000000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveConfig,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.skyBottom,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Sauvegarder'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_isSendingConfig || _phoneController.text.isEmpty || !_operatorConfirmed)
                            ? null
                            : _sendConfigSmsCommands,
                        icon: _isSendingConfig
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isSendingConfig
                            ? 'Envoi en cours...'
                            : (!_operatorConfirmed ? 'Sélectionnez un opérateur' : 'Renvoyer les commandes SMS')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
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
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Comment trouver votre IP?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('1. Ouvrez cmd sur votre PC'),
                    const Text('2. Tapez: ipconfig'),
                    const Text('3. Cherchez "Adresse IPv4"'),
                    const Text('4. Utilisez cette adresse ici'),
                    const SizedBox(height: 12),
                    const Text(
                      'Exemple: 192.168.1.100',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
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
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Vérifications importantes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('✓ Le serveur doit être démarré'),
                    const Text('✓ Le PC et le téléphone sur le même WiFi'),
                    const Text('✓ Le pare-feu doit autoriser Python'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



