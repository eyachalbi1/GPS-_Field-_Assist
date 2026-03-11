import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../services/operator_service.dart';
import '../services/sms_history_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gps_device_service.dart';
import '../models/sms_history.dart';
import '../services/sms_history_service.dart';
import 'sms_history_screen.dart';
import 'sequential_sms_screen.dart';

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

  String? _lastSmsResponse;
  String? _smsStatus;
  bool _smsSent = false;
  String? _lastSentCommand;
  String? _lastSentPhone;
  StreamSubscription<SmsMessage>? _smsSubscription;
  bool _isDataValid = true;
  String _validationMessage = '';
  final List<Map<String, String>> _smsHistory = [];
  Timer? _pollingTimer;
  Timer? _devicesRefreshTimer;
  StreamSubscription<List<GpsDevice>>? _devicesSubscription;
  List<Map<String, String?>> _examples = [];
  bool _isLoadingDevices = true;
  String? _currentSmsId;
  int? _lastSmsCheckTime;

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

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
    {'command': 'APN,internet.tn#', 'description': 'APN Telecom'},
    {'command': 'APN,apn.tunav.tn#', 'description': 'APN Orange'},
    {'command': 'APN,m2m.tunav.com,tunav,tunav#', 'description': 'APN Ooredoo'},
    {'command': 'PROTOCOL,3,1#', 'description': 'Set protocol'},
    {'command': 'IP,41.226.27.169,85,1#', 'description': 'Set IP primary'},
    {'command': 'IP2,41.226.27.169,84,1#', 'description': 'Set IP secondary'},
    {'command': 'LEVEL,5#', 'description': 'Set level'},
    {'command': 'HC,60,7200,7200#', 'description': 'Set heartbeat config'},
    {'command': 'CORNER,20#', 'description': 'Set corner angle'},
    {'command': 'ZD,0#', 'description': 'Set ZD parameter'},
    {'command': 'WY,1,500,0#', 'description': 'Set WY parameter'},
    {'command': 'UTC,0#', 'description': 'Set UTC timezone'},
    {'command': 'VACC,0#', 'description': 'Set VACC parameter'},
    {'command': 'COLLISION,0#', 'description': 'Collision detection'},
    {'command': 'SLEEP,0#', 'description': 'Sleep mode'},
    {'command': 'ALARMSPEED,ON,120#', 'description': 'Speed alarm (120 km/h)'},
    {'command': 'SENALM,OFF#', 'description': 'Sensor alarm OFF'},
    {'command': 'MOVING,OFF#', 'description': 'Moving alarm OFF'},
    {'command': 'LINE,4,1#', 'description': 'Set line parameter'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDevicesFromApi();
    _startDevicesAutoRefresh();
    _applyTestCommand(0);

    _devicesSubscription = GpsDeviceService.devicesStream.listen((devices) {
      if (!mounted) return;
      final loaded = devices.map((d) => d.toMap()).toList();
      // Try to find exact module matching widget.moduleName
      int matchIndex = loaded.indexWhere((ex) =>
          (ex['SerialNumber'] ?? '').trim() == widget.moduleName.trim());

      setState(() {
        _examples = loaded;
        if (matchIndex >= 0) {
          _applyExample(matchIndex, notify: false);
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestSmsPermissions();
    });
  }

  void _startDevicesAutoRefresh() {
    _devicesRefreshTimer?.cancel();
    _devicesRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadDevicesFromApi(silent: true),
    );
  }

  Future<void> _loadDevicesFromApi({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingDevices = true);
    }

    try {
      final devices = await GpsDeviceService.fetchDevices();
      final loadedExamples = devices.map((device) => device.toMap()).toList();
      if (!mounted) return;

      if (loadedExamples.isNotEmpty) {
        _examples = loadedExamples;

        // Prefer exact match by moduleName (SerialNumber)
        int indexToApply = _examples.indexWhere((ex) =>
            (ex['SerialNumber'] ?? '').trim() == widget.moduleName.trim());

        // If no exact match, try to use existing selected serial
        if (indexToApply < 0) {
          final selectedSerial = _serialController.text.trim();
          if (selectedSerial.isNotEmpty) {
            final currentIndex = _examples.indexWhere(
              (ex) => (ex['SerialNumber'] ?? '').trim() == selectedSerial,
            );
            if (currentIndex >= 0) indexToApply = currentIndex;
          }
        }

        // Fallback: pick first
        if (indexToApply < 0) indexToApply = 0;

        _applyExample(indexToApply, notify: false);
      } else if (_examples.isEmpty) {
        // Pas de données API — tenter fallback depuis l'historique local
        final history = await SmsHistoryService.getHistory();
        // Chercher la dernière entrée correspondant à ce module
        SmsHistoryItem? lastForModule;
        if (history.isEmpty) {
          lastForModule = null;
        } else {
          lastForModule = history.firstWhere(
            (h) => h.moduleName != null && h.moduleName == widget.moduleName,
            orElse: () => history.first,
          );
        }

        if (lastForModule != null) {
          // Remplir au moins le numéro de téléphone depuis l'historique
          _phoneController.text = lastForModule.phone.trim();
          // Si les exemples sont vides on peut utiliser le numéro comme SIM
          _simController.text = lastForModule.phone.trim();
        } else {
          _serialController.clear();
          _simController.clear();
          _equipmentController.clear();
          _passwordController.clear();
          _phoneController.clear();
        }
      }
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _requestSmsPermissions() async {
    try {
      final hasPermission = await _telephony.requestSmsPermissions;
      if (hasPermission == true) {
        _startSmsListener();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                      'Ecoute SMS activee - Les reponses GPS s\'afficheront automatiquement'),
                ],
              ),
              backgroundColor: Color(0xFF2ECC71),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Permission SMS refusee - Allez dans Parametres > Apps > gps_field_assist > Autorisations > SMS')),
                ],
              ),
              backgroundColor: Color(0xFFFFA500),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail on permission error - user can use default SMS app instead
    }
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
    _pollingTimer?.cancel();
    _devicesRefreshTimer?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }

  void _startSmsListener() {
    if (_isListening) return;

    debugPrint('=== DEMARRAGE SMS LISTENER ===');

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        _handleIncomingSms(message);
      },
      listenInBackground: false,
    );

    // Démarrer aussi un polling pour vérifier les SMS toutes les 3 secondes
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkForNewSms();
    });

    setState(() {
      _isListening = true;
    });
    debugPrint('SMS Listener actif avec polling');
  }

  void _handleIncomingSms(SmsMessage message) {
    final body = message.body ?? '';
    final sender = message.address ?? '';

    debugPrint('=== SMS RECU ===');
    debugPrint('De: $sender');
    debugPrint('Message: $body');

    // Vérifier si c'est du numéro attendu
    if (_lastSentPhone != null) {
      final normalizedSender = _normalizePhone(sender);
      final normalizedExpected = _normalizePhone(_lastSentPhone!);

      if (normalizedSender != normalizedExpected) {
        debugPrint(
            'SMS ignoré - expéditeur différent: $normalizedSender vs $normalizedExpected');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // device title and count removed for visibility
            'response': body,
            'time': DateTime.now().toString().substring(11, 19),
            'status': 'received',
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.message, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Reponse GPS recue: ${body.substring(0, body.length > 30 ? 30 : body.length)}...')),
            ],
          ),
          backgroundColor: const Color(0xFF2ECC71),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _checkForNewSms() async {
    if (_lastSentPhone == null || _smsHistory.isEmpty) return;
    if (_smsHistory[0]['status'] != 'sent') return;

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals(_normalizePhone(_lastSentPhone!)),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty) {
        final lastMsg = messages.first;
        final msgDate = lastMsg.date;

        // Vérifier si c'est un nouveau message (msgDate est un timestamp en millisecondes)
        if (msgDate != null &&
            (_lastSmsCheckTime == null || msgDate > _lastSmsCheckTime!)) {
          _lastSmsCheckTime = msgDate;
          _handleIncomingSms(lastMsg);
        }
      }
    } catch (e) {
      // Silent fail on SMS polling
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
              _isDataValid ? const Color(0xFF2ECC71) : const Color(0xFFFFA500),
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
          'Données invalides: SerialNumber et EquipmentType requis';
      return;
    }

    if (serial.length < 5) {
      _isDataValid = false;
      _validationMessage = 'Données invalides: SerialNumber trop court';
      return;
    }

    if (sim.isEmpty || sim == ' ') {
      _isDataValid = true;
      _validationMessage =
          'Attention: SIMCardNumber manquant mais données valides';
      return;
    }

    _isDataValid = true;
    _validationMessage = 'Données valides';
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
    // Simple SMS without detailed configuration info
    return 'TEST GPS';
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

  Future<void> _sendSms({required bool isTestCommand}) async {
    final targetPhone = _normalizePhone(_phoneController.text);
    if (targetPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Erreur: Numero de telephone requis'),
            ],
          ),
          backgroundColor: Color(0xFFDC143C),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final smsBody =
        isTestCommand ? _buildTestCommandMessage() : _buildSmsMessage();

    setState(() {
      _lastSmsResponse = null;
      _lastSentCommand = smsBody;
      _lastSentPhone = targetPhone;
      _lastSmsCheckTime = DateTime.now().millisecondsSinceEpoch;
      _isSending = true;
    });

    await _sendDirectSms(targetPhone, smsBody);
  }

  Future<void> _sendDirectSms(String phone, String message) async {
    try {
      // Créer l'ID du SMS et l'ajouter à l'historique immédiatement
      final smsId = DateTime.now().millisecondsSinceEpoch.toString();
      final historyItem = SmsHistoryItem(
        id: smsId,
        phone: phone,
        command: message,
        response: null,
        timestamp: DateTime.now(),
        status: SmsHistoryStatus.pending,
        moduleName: widget.moduleName,
      );

      await SmsHistoryService.addToHistory(historyItem);

      await _telephony.sendSms(
        to: phone,
        message: message,
        statusListener: (SendStatus status) {
          if (!mounted) return;

          if (status == SendStatus.SENT) {
            SmsHistoryService.updateStatus(smsId, SmsHistoryStatus.sent);

            setState(() {
              _smsStatus = 'SMS envoye avec succes';
              _smsSent = true;
              _isSending = false;

              // Ajouter le SMS envoyé à l'historique local
              if (_lastSentCommand != null) {
                _smsHistory.insert(0, {
                  'command': _lastSentCommand!,
                  'response': 'En attente de reponse...',
                  'time': DateTime.now().toString().substring(11, 19),
                  'status': 'sent',
                });
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('SMS envoye avec succes'),
                  ],
                ),
                backgroundColor: Color(0xFF2ECC71),
                duration: Duration(seconds: 3),
              ),
            );
          } else if (status == SendStatus.DELIVERED) {
            SmsHistoryService.updateStatus(smsId, SmsHistoryStatus.delivered);
            debugPrint('SMS delivered');
          }
        },
      );
    } catch (e) {
      // Silent fail on SMS send error
    }
  }

  void _clearResponse() {
    setState(() {
      _lastSmsResponse = null;
      _smsStatus = null;
      _lastSentCommand = null;
    });
  }

  Future<void> _checkRecentSms() async {
    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty) {
        final lastMsg = messages.first;
        debugPrint('Dernier SMS: ${lastMsg.body} de ${lastMsg.address}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Dernier SMS: ${lastMsg.body?.substring(0, lastMsg.body!.length > 50 ? 50 : lastMsg.body!.length)}...'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture SMS: $e');
    }
  }

  // Show details popup for the selected module
  void _showSelectedModuleDetails() {
    if (_examples.isEmpty) return;

    final ex = _examples[_selectedExampleIndex];
    final serialNumber = (ex['SerialNumber'] ?? '').trim();
    final simCardNumber = (ex['SIMCardNumber'] ?? '').trim();
    final equipmentType = (ex['EquipmentType'] ?? '').trim();
    final passwordDevice = (ex['PasswordDevice'] ?? '').trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C4D7A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'Détails du Module',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildDetailRow('SerialNumber', serialNumber),
              _buildDetailRow('SIMCardNumber', simCardNumber),
              _buildDetailRow('EquipmentType', equipmentType),
              _buildDetailRow('PasswordDevice', passwordDevice),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            // Title and device-count removed for better visibility (UI simplified)
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurer ${widget.moduleName}'),
        backgroundColor: const Color(0xFF0C4D7A),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SmsHistoryScreen(),
                ),
              );
            },
            tooltip: 'Historique SMS',
          ),
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
              // Operator logos row (shows current operator; tap to open server config)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _operatorLogo(MobileOperator.telecom, 'assets/logo_telecom.png'),
                      _operatorLogo(MobileOperator.orange, 'assets/logo_orange.png'),
                      _operatorLogo(MobileOperator.ooredoo, 'assets/logo_ooredoo.png'),
                    ],
                  ),
                ),
              ),
              if (_smsStatus != null)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _smsSent
                        ? const Color(0xFF3498DB).withOpacity(0.95)
                        : const Color(0xFFFFA500).withOpacity(0.95),
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
                              'Reponse GPS recue:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (_lastSentCommand != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Commande: $_lastSentCommand',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _lastSmsResponse!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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
              if (_smsHistory.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _smsHistory.length,
                    itemBuilder: (context, index) {
                      final item = _smsHistory[index];
                      final isWaiting = item['status'] == 'sent';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isWaiting
                                ? const Color(0xFFFFA500).withOpacity(0.5)
                                : const Color(0xFF2ECC71).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  item['time']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                if (isWaiting)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFA500)),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _smsHistory.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3498DB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.send,
                                      size: 14, color: Color(0xFF3498DB)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item['command']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3498DB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isWaiting
                                    ? const Color(0xFFFFA500).withOpacity(0.1)
                                    : const Color(0xFF2ECC71).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isWaiting
                                        ? Icons.hourglass_empty
                                        : Icons.reply,
                                    size: 14,
                                    color: isWaiting
                                        ? const Color(0xFFFFA500)
                                        : const Color(0xFF2ECC71),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item['response']!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isWaiting
                                            ? const Color(0xFFFFA500)
                                            : Colors.black87,
                                        fontStyle: isWaiting
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                        _buildConfigTab(),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white54, thickness: 1),
                        const SizedBox(height: 20),
                        _buildTestCommandsTab(),
                      ],
                    ),
                  ),
                ),
              ),
              
              // end SMS status
            ],
          ),
        ),
      ),
    );
  }

  Widget _operatorLogo(MobileOperator operator, String assetPath) {
    final isSelected = Config.selectedOperator == operator;
    return GestureDetector(
      onTap: () async {
        // Select operator here (used for SMS sending) and persist
        setState(() {
          Config.setSelectedOperator(operator);
        });
        await Config.saveConfig();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opérateur sélectionné: ${operator.name}'),
            backgroundColor: const Color(0xFF2ECC71),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: isSelected ? 1.0 : 0.45,
            child: Image.asset(
              assetPath,
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.signal_cellular_alt, size: 40),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            operator.name.isNotEmpty ? (operator.name[0].toUpperCase() + operator.name.substring(1)) : operator.name,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildConfigTab() {
    if (_isLoadingDevices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Chargement des dispositifs GPS...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Device title and count removed for improved visibility
        const SizedBox(height: 8),
        // Info button to show all module details
        if (_examples.isNotEmpty)
          IconButton(
            onPressed: () => _showSelectedModuleDetails(),
            icon: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Voir les details du module',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(8),
            ),
          ),
        if (_examples.isNotEmpty)
          // Afficher les details specifiques du module selectionne
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type de module
                Row(
                  children: [
                    const Icon(Icons.devices,
                        color: Color(0xFF0C4D7A), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _equipmentController.text.isNotEmpty
                          ? _equipmentController.text
                          : (_examples[_selectedExampleIndex]
                                  ['EquipmentType'] ??
                              'N/A'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C4D7A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // SerialNumber
                Row(
                  children: [
                    const Icon(Icons.numbers, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SN: ${_serialController.text.isNotEmpty ? _serialController.text : (_examples[_selectedExampleIndex]['SerialNumber'] ?? 'N/A')}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                // SIM Card
                if (_simController.text.isNotEmpty ||
                    (_examples[_selectedExampleIndex]['SIMCardNumber'] ?? '')
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.sim_card, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SIM: ${_simController.text.isNotEmpty ? _simController.text : (_examples[_selectedExampleIndex]['SIMCardNumber'] ?? 'N/A')}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA500).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFFFFA500).withOpacity(0.4)),
            ),
            child: const Text(
              'Aucune donnee disponible depuis l API. Verifiez la connexion serveur puis rechargez.',
              style: TextStyle(color: Colors.white),
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
          onPressed: () {
            final phone = _phoneController.text.trim();
            if (phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrez un numero de telephone'),
                  backgroundColor: Color(0xFFDC143C),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SequentialSmsScreen(
                  phoneNumber: phone,
                  moduleName: widget.moduleName,
                ),
              ),
            );
          },
          icon: const Icon(Icons.send_and_archive),
          label: const Text('Envoi Sequentiel des Commandes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B59B6),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
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
