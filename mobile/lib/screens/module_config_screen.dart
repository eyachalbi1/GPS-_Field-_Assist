import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

class ModuleConfigScreen extends StatefulWidget {
  final String moduleName;

  const ModuleConfigScreen({super.key, required this.moduleName});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  final Telephony _telephony = Telephony.instance;
  final _serialController = TextEditingController();
  final _simController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imeiController = TextEditingController();
  final _commandController = TextEditingController();

  bool _isSending = false;
  bool _isListening = false;
  int _selectedExampleIndex = 0;
  int _selectedCommandIndex = 0;
  int _selectedTabIndex = 0;
  String? _lastSmsResponse;
  String? _smsStatus;
  bool _smsSent = false;
  StreamSubscription<SmsMessage>? _smsSubscription;
  bool _isDataValid = true;
  String _validationMessage = '';

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static const List<Map<String, String?>> _examples = [
    {
      'SerialNumber': '862407128000768',
      'SIMCardNumber': '52223006',
      'EquipmentType': 'EasyTraceX',
      'PasswordDevice': '',
    },
    {
      'SerialNumber': '000088120625216',
      'SIMCardNumber': '',
      'EquipmentType': 'EasyTraceX',
      'PasswordDevice': '',
    },
    {
      'SerialNumber': '008GT01651',
      'SIMCardNumber': ' ',
      'EquipmentType': 'EasyTrace',
      'PasswordDevice': '',
    },
    {
      'SerialNumber': '0090568',
      'SIMCardNumber': '',
      'EquipmentType': 'MiniTrace',
      'PasswordDevice': null,
    },
    {
      'SerialNumber': '0104070001',
      'SIMCardNumber': '1008GT01974',
      'EquipmentType': 'EasyTrace',
      'PasswordDevice': null,
    },
    {
      'SerialNumber': '0104070002',
      'SIMCardNumber': '22 222 222',
      'EquipmentType': 'EasyTrace',
      'PasswordDevice': null,
    },
    {
      'SerialNumber': '0104070003',
      'SIMCardNumber': null,
      'EquipmentType': 'EasyTrace',
      'PasswordDevice': null,
    },
    {
      'SerialNumber': '011691002493420',
      'SIMCardNumber': ' 26395600',
      'EquipmentType': 'MTMVT380',
      'PasswordDevice': '',
    },
    {
      'SerialNumber': '011691003906792',
      'SIMCardNumber': '00 000 000',
      'EquipmentType': 'CbnBan103',
      'PasswordDevice': '',
    },
    {
      'SerialNumber': '0-1246733',
      'SIMCardNumber': '',
      'EquipmentType': 'SmartOneBVMD',
      'PasswordDevice': '',
    },
  ];

  static const List<Map<String, String>> _testCommands = [
    {'command': '*11*4#', 'description': 'Check IP + IMEI + Online/Offline'},
    {'command': '*11*3#', 'description': 'Check position'},
    {'command': 'STATUS#', 'description': 'Check contact/fuel supply'},
    {
      'command': 'CLR,BLIND#',
      'description': 'Clear history (permission required)'
    },
    {'command': 'RESET#', 'description': 'Restart (wait 30s)'},
    {'command': '*77*6*IMEI#', 'description': 'Restore IMEI if lost'},
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.moduleName.hashCode.abs() % _examples.length;
    _applyExample(initialIndex, notify: false);
    _applyTestCommand(0);
    _startSmsListener();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _simController.dispose();
    _equipmentController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _imeiController.dispose();
    _commandController.dispose();
    _stopSmsListener();
    super.dispose();
  }

  void _startSmsListener() {
    if (_isListening) return;

    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (!mounted) return;

          final sender = message.address ?? '';
          final body = message.body ?? '';
          final timestamp = DateTime.now();

          setState(() {
            _lastSmsResponse = body;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reponse GPS recue!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: const Color(0xFF2ECC71),
              duration: const Duration(seconds: 10),
            ),
          );
        },
      );

      setState(() {
        _isListening = true;
      });
    } catch (e) {
      debugPrint('Error starting SMS listener: $e');
    }
  }

  void _stopSmsListener() {
    _smsSubscription?.cancel();
    _smsSubscription = null;
    setState(() {
      _isListening = false;
    });
  }

  void _applyExample(int index, {bool notify = true}) {
    final ex = _examples[index];
    _selectedExampleIndex = index;
    _serialController.text = (ex['SerialNumber'] ?? '').trim();
    _simController.text = (ex['SIMCardNumber'] ?? '').trim();
    _equipmentController.text = (ex['EquipmentType'] ?? '').trim();
    _passwordController.text = (ex['PasswordDevice'] ?? '').trim();
    _phoneController.text = _simController.text;

    _validateData();

    if (notify && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isDataValid ? Icons.check_circle : Icons.warning,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_validationMessage)),
            ],
          ),
          backgroundColor:
              _isDataValid ? const Color(0xFF2ECC71) : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _validateData() {
    final serial = _serialController.text.trim();
    final sim = _simController.text.trim();
    final equipment = _equipmentController.text.trim();

    if (serial.isEmpty || equipment.isEmpty) {
      _isDataValid = false;
      _validationMessage =
          'DonnÃ©es invalides: SerialNumber et EquipmentType requis';
      return;
    }

    if (serial.length < 5) {
      _isDataValid = false;
      _validationMessage = 'DonnÃ©es invalides: SerialNumber trop court';
      return;
    }

    if (sim.isEmpty || sim == ' ') {
      _isDataValid = false;
      _validationMessage = 'Attention: SIMCardNumber manquant';
      return;
    }

    _isDataValid = true;
    _validationMessage = 'DonnÃ©es valides';
  }

  void _applyTestCommand(int index) {
    final cmd = _testCommands[index];
    _selectedCommandIndex = index;
    _commandController.text = cmd['command'] ?? '';
    if (mounted) {
      setState(() {});
    }
  }

  String _buildSmsMessage() {
    return [
      'CONFIG ${widget.moduleName}',
      'SerialNumber: ${_serialController.text.trim()}',
      'SIMCardNumber: ${_simController.text.trim()}',
      'EquipmentType: ${_equipmentController.text.trim()}',
      'PasswordDevice: ${_passwordController.text.trim()}',
    ].join('\n');
  }

  String _buildTestCommandMessage() {
    String cmd = _commandController.text.trim();

    if (cmd.contains('IMEI')) {
      final imei = _imeiController.text.trim();
      if (imei.isNotEmpty) {
        cmd = cmd.replaceAll('IMEI', imei);
      }
    }

    return cmd;
  }

  Future<bool> _openSmsAppFallback({
    required String phone,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendSms({required bool isTestCommand}) async {
    final targetPhone = _normalizePhone(_phoneController.text);
    if (targetPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Entrez un numero de telephone pour le test SMS')),
      );
      return;
    }

    final smsBody =
        isTestCommand ? _buildTestCommandMessage() : _buildSmsMessage();

    setState(() {
      _lastSmsResponse = null;
      _smsStatus = 'Envoi en cours...';
      _smsSent = false;
    });

    if (!Platform.isAndroid) {
      setState(() {
        _smsStatus = 'Erreur: Android uniquement';
        _smsSent = false;
      });
      return;
    }

    setState(() => _isSending = true);

    try {
      final canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) {
        if (!mounted) return;
        setState(() {
          _smsStatus = 'Erreur: Telephone non compatible';
          _smsSent = false;
        });
        return;
      }

      final hasPermission = await _telephony.requestSmsPermissions;
      if (hasPermission != true) {
        if (!mounted) return;
        setState(() {
          _smsStatus = 'Erreur: Permission refusee';
          _smsSent = false;
        });
        return;
      }

      try {
        await _telephony.sendSms(
          to: targetPhone,
          message: smsBody,
          isMultipart: smsBody.length > 160,
          statusListener: (status) {
            if (!mounted) return;

            switch (status) {
              case SendStatus.DELIVERED:
                setState(() {
                  _smsStatus = 'SMS livre avec succes';
                  _smsSent = true;
                });
                break;
              case SendStatus.SENT:
                setState(() {
                  _smsStatus = 'SMS envoye - En attente de reponse';
                  _smsSent = true;
                });
                break;
              default:
                setState(() {
                  _smsStatus = 'Envoi en cours...';
                  _smsSent = false;
                });
            }
          },
        );

        if (!mounted) return;
        setState(() {
          _smsStatus = 'SMS envoye - En attente de reponse';
          _smsSent = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _smsStatus = 'Erreur: Echec envoi SMS';
          _smsSent = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _smsStatus = 'Erreur: $e';
        _smsSent = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _clearResponse() {
    setState(() {
      _lastSmsResponse = null;
      _smsStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurer ${widget.moduleName}'),
        backgroundColor: const Color(0xFF0C4D7A),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isListening ? Icons.sms : Icons.sms_outlined,
                  color:
                      _isListening ? const Color(0xFF2ECC71) : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isListening ? 'Ecoute' : 'Off',
                  style: TextStyle(
                    color:
                        _isListening ? const Color(0xFF2ECC71) : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fond tunav.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_smsStatus != null)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _smsSent
                        ? const Color(0xFF3498DB).withOpacity(0.95)
                        : Colors.orange.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _smsSent ? Icons.check_circle : Icons.error_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _smsStatus!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                        onPressed: () => setState(() => _smsStatus = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              if (_lastSmsResponse != null)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.message, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Réponse GPS reçue:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastSmsResponse!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _clearResponse,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedTabIndex = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 0
                                          ? const Color(0xFF48C9B0)
                                              .withOpacity(0.5)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Configuration',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedTabIndex == 0
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedTabIndex = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1
                                          ? const Color(0xFF48C9B0)
                                              .withOpacity(0.5)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Commandes Test',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedTabIndex == 1
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedTabIndex == 0) ...[
                          _buildConfigTab(),
                        ] else ...[
                          _buildTestCommandsTab(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisir un exemple',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<int>(
            value: _selectedExampleIndex,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: List.generate(
              _examples.length,
              (index) {
                final serial = _examples[index]['SerialNumber'] ?? '';
                return DropdownMenuItem<int>(
                  value: index,
                  child: Text('Exemple ${index + 1} - $serial'),
                );
              },
            ),
            onChanged: (value) {
              if (value == null) return;
              _applyExample(value);
            },
          ),
        ),
        const SizedBox(height: 14),
        _buildField('SerialNumber', _serialController, Icons.numbers),
        const SizedBox(height: 12),
        _buildField(
          'SIMCardNumber (test avec numero telephone)',
          _simController,
          Icons.sim_card,
        ),
        const SizedBox(height: 12),
        _buildField('EquipmentType', _equipmentController,
            Icons.precision_manufacturing),
        const SizedBox(height: 12),
        _buildField('PasswordDevice', _passwordController, Icons.password),
        const SizedBox(height: 12),
        _buildField(
          'Numero telephone destination',
          _phoneController,
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _isSending ? null : () => _sendSms(isTestCommand: false),
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sms),
          label: Text(_isSending ? 'Envoi...' : 'Envoyer SMS Config'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF48C9B0),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCommandsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisir une commande',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<int>(
            value: _selectedCommandIndex,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: List.generate(
              _testCommands.length,
              (index) {
                final cmd = _testCommands[index];
                return DropdownMenuItem<int>(
                  value: index,
                  child: Text('${cmd['command']} - ${cmd['description']}'),
                );
              },
            ),
            onChanged: (value) {
              if (value == null) return;
              _applyTestCommand(value);
            },
          ),
        ),
        const SizedBox(height: 14),
        if (_commandController.text.contains('IMEI')) ...[
          _buildField(
            'IMEI du module',
            _imeiController,
            Icons.memory,
          ),
          const SizedBox(height: 12),
        ],
        _buildField(
          'Commande',
          _commandController,
          Icons.terminal,
        ),
        const SizedBox(height: 12),
        _buildField(
          'Numero telephone du module GPS',
          _phoneController,
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _isSending ? null : () => _sendSms(isTestCommand: true),
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send),
          label: Text(_isSending ? 'Envoi...' : 'Envoyer Commande'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0C4D7A)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
