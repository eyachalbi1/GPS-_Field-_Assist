import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'package:telephony/telephony.dart';
import '../services/operator_service.dart';
import '../services/sms_history_service.dart';
import '../services/gps_device_service.dart';
import '../models/sms_history.dart';
import 'sms_history_screen.dart';

class ModuleConfigScreen extends StatefulWidget {
  final String moduleName;

  const ModuleConfigScreen({super.key, required this.moduleName});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

enum _CommandProgress {
  pending,
  sent,
  confirmed,
  failed,
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  final Telephony _telephony = Telephony.instance;
  final _serialController = TextEditingController();
  final _simController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSending = false;
  bool _isListening = false;
  int _selectedExampleIndex = 0;

  String? _lastSentCommand;
  String? _lastSentPhone;
  StreamSubscription<SmsMessage>? _smsSubscription;
  bool _isDataValid = true;
  String _validationMessage = '';
  Timer? _pollingTimer;
  Timer? _devicesRefreshTimer;
  StreamSubscription<List<GpsDevice>>? _devicesSubscription;
  List<Map<String, dynamic>> _examples = [];
  bool _isLoadingDevices = true;
  String? _currentSmsId;
  int? _lastSmsCheckTime;
  Timer? _responseTimer;
  bool _isSequentialSending = false;
  bool _isWaitingForResponse = false;
  int _nextCommandIndex = 0;
  int? _currentCommandIndex;
  MobileOperator? _selectedOperatorForSequential;
  List<Map<String, String>> _sequenceCommands = [];
  List<_CommandProgress> _commandProgress = [];
  final Map<int, String> _commandResponses = {};
  int _attemptCount = 0;

  static const int _replyTimeoutS = 60;

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // Commandes EasyTrace (format &&IMEI,pass,Zxx,...)
  List<Map<String, String>> _buildEasyTraceCommands() {
    final imei = _serialController.text.trim();
    final pass = _passwordController.text.trim().isEmpty
        ? 'pass'
        : _passwordController.text.trim();
    final selected = _selectedOperatorForSequential ?? Config.selectedOperator;

    // APN selon opérateur
    final apnValues = {
      MobileOperator.telecom: 'internet.tn',
      MobileOperator.orange: 'apn.tunav.tn',
      MobileOperator.ooredoo: 'm2m.tunav.com',
    };
    final apn = apnValues[selected] ?? 'internet.tn';
    final operatorName = Config.operatorNames[selected] ?? '';

    return [
      {'command': '&&$imei,$pass,Z10,$apn', 'description': 'APN $operatorName'},
      {
        'command': '&&$imei,$pass,Z39,1,41.226.24.13,1200,1',
        'description': 'IP & Port'
      },
      {
        'command': '&&$imei,$pass,Z31,60,600,60,600,60,600,5,1',
        'description': 'Time Report'
      },
      {
        'command': '&&$imei,$pass,Z36,0.7,3,3,1',
        'description': 'Distance Report'
      },
      {'command': '&&$imei,$pass,Z37,25,2,1', 'description': 'Angle Report'},
      {
        'command': '&&$imei,$pass,Z80,1,0',
        'description': 'Contact ON/OFF Report'
      },
      {
        'command': '&&$imei,$pass,Z27,1.0,0',
        'description': 'Lock GPS when ACC off'
      },
    ];
  }

  bool get _isEasyTraceVII {
    final eq = _equipmentController.text.trim().toLowerCase();
    return eq.contains('easytrace') && (eq.contains('vii') || eq.contains('7'));
  }

  bool get _isEasyCanTrace {
    final eq = _equipmentController.text.trim().toLowerCase();
    return eq.contains('easycantrace') ||
        eq.contains('gv300can') ||
        eq.contains('easycan') ||
        eq.contains('etcan');
  }

  // List of configuration commands that require operator to be selected
  // These are the ONLY commands that should be shown after operator selection
  static const List<Map<String, String>> _configCommands = [
    {'command': 'PROTOCOL,3,1#', 'description': 'Set protocol'},
    {'command': 'IP,41.226.27.169,85,1#', 'description': 'Set IP primary'},
    {'command': 'HC,60,7200,7200#', 'description': 'Set heartbeat config'},
    {'command': 'CORNER,20#', 'description': 'Set corner angle'},
    {'command': 'UTC,0#', 'description': 'Set UTC timezone'},
    {'command': 'SLEEP,0#', 'description': 'Sleep mode'},
    {'command': 'LINE,4,1#', 'description': 'Set line parameter'},
    {'command': 'DISTANCE#', 'description': 'Set distance parameter'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDevicesFromApi();
    _startDevicesAutoRefresh();
    _selectedOperatorForSequential = Config.selectedOperator;
    _refreshSequenceCommands();
    _loadCommandProgressFromHistory();

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

  void _refreshSequenceCommands() {
    if (_isEasyTraceVII) {
      // Commandes spécifiques EasyTraceVII
      _sequenceCommands = _buildEasyTraceCommands();

      // Commandes pour EasyCanTrace + mise à jour FW
      final selected =
          _selectedOperatorForSequential ?? Config.selectedOperator;
      final operatorName = Config.operatorNames[selected] ?? '';
      final apnCommand = Config.apnCommands[selected] ?? '';
      final commands = <Map<String, String>>[];
      if (apnCommand.isNotEmpty) {
        commands.add({
          'command': apnCommand,
          'description':
              'APN ${operatorName.isNotEmpty ? operatorName : ''}'.trim(),
        });
      }
      commands.addAll(_configCommands);
      // Ajout commande mise à jour firmware (même que diagnostic)
      commands.add({
        'command':
            'AT+GTUPD=gv300can,0,0,20,0,,,http://41.226.24.13:5000/api/download/GV300CANR00_0B08_to_0C10.bin,,0,,,0001\$',
        'description': 'Mise à jour Firmware EasyCanTrace'
      });
      _sequenceCommands = commands;
    } else {
      // Commandes standard (autres modules)
      final selected =
          _selectedOperatorForSequential ?? Config.selectedOperator;
      final operatorName = Config.operatorNames[selected] ?? '';
      final apnCommand = Config.apnCommands[selected] ?? '';
      final commands = <Map<String, String>>[];
      if (apnCommand.isNotEmpty) {
        commands.add({
          'command': apnCommand,
          'description':
              'APN ${operatorName.isNotEmpty ? operatorName : ''}'.trim(),
        });
      }
      commands.addAll(_configCommands);
      _sequenceCommands = commands;
    }
    _commandProgress = List<_CommandProgress>.filled(
      _sequenceCommands.length,
      _CommandProgress.pending,
    );
    _commandResponses.clear();
  }

  Future<void> _loadCommandProgressFromHistory() async {
    try {
      final history = await SmsHistoryService.getHistory();
      final Map<String, SmsHistoryItem> latestByCommand = {};

      for (final item in history) {
        if (item.moduleName != widget.moduleName) continue;
        final command = item.command;
        if (_sequenceCommands.indexWhere((c) => c['command'] == command) < 0) {
          continue;
        }

        final existing = latestByCommand[command];
        if (existing == null || item.timestamp.isAfter(existing.timestamp)) {
          latestByCommand[command] = item;
        }
      }

      final progress = List<_CommandProgress>.filled(
        _sequenceCommands.length,
        _CommandProgress.pending,
      );

      for (int i = 0; i < _sequenceCommands.length; i++) {
        final command = _sequenceCommands[i]['command'];
        if (command == null) continue;
        final item = latestByCommand[command];
        if (item == null) continue;

        switch (item.status) {
          case SmsHistoryStatus.received:
            progress[i] = _CommandProgress.confirmed;
            break;
          case SmsHistoryStatus.sent:
          case SmsHistoryStatus.delivered:
          case SmsHistoryStatus.pending:
            progress[i] = _CommandProgress.sent;
            break;
          case SmsHistoryStatus.failed:
            progress[i] = _CommandProgress.failed;
            break;
        }
      }

      int nextIndex =
          progress.indexWhere((p) => p != _CommandProgress.confirmed);
      if (nextIndex < 0) nextIndex = _sequenceCommands.length;

      if (!mounted) return;
      setState(() {
        _commandProgress = progress;
        _nextCommandIndex = nextIndex;
      });
    } catch (e) {
      debugPrint('Erreur chargement progression commandes: $e');
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
    _stopSmsListener();
    _pollingTimer?.cancel();
    _responseTimer?.cancel();
    _devicesRefreshTimer?.cancel();
    _devicesSubscription?.cancel();
    _smsSubscription?.cancel();
    super.dispose();
  }

  void _startSmsListener() {
    if (_isListening) return;

    debugPrint('=== DEMARRAGE SMS LISTENER ===');

    // Start listening for incoming SMS
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        debugPrint('=== SMS DETECTE PAR LISTENER ===');
        _handleIncomingSms(message);
      },
      listenInBackground: true,
    );

    // Polling toutes les 3s pour capturer les SMS manqués par le listener
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkForNewSms();
    });

    setState(() {
      _isListening = true;
    });
    debugPrint('SMS Listener started with polling');
  }

  // Vérifie si l'expéditeur correspond au numéro GPS attendu (comparaison souple)
  bool _senderMatches(String sender, String expected) {
    if (sender.isEmpty || expected.isEmpty) return true; // accepter si inconnu
    final s = sender.replaceAll(RegExp(r'[^0-9]'), '');
    final e = expected.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty || e.isEmpty) return true;
    // Correspondance si l'un se termine par l'autre (gère +216 vs local)
    return s.endsWith(e) || e.endsWith(s);
  }

  void _handleIncomingSms(SmsMessage? message) {
    if (message == null) return;

    final body = message.body ?? '';
    final sender = message.address ?? '';

    debugPrint('=== SMS RECU === De: $sender | Body: $body');

    if (body.isEmpty) return;

    if (!_isWaitingForResponse) {
      debugPrint('SMS ignore (pas en attente de reponse)');
      return;
    }

    // Filtre expéditeur souple
    if (_lastSentPhone != null && !_senderMatches(sender, _lastSentPhone!)) {
      debugPrint(
          'SMS ignore (expediteur non attendu: $sender vs $_lastSentPhone)');
      return;
    }

    // Anti-doublon : ignorer si même date qu'un SMS déjà traité
    final msgDate = message.date;
    if (msgDate != null &&
        _lastSmsCheckTime != null &&
        msgDate <= _lastSmsCheckTime!) {
      debugPrint('SMS ignore (deja traite, date: $msgDate)');
      return;
    }
    if (msgDate != null) _lastSmsCheckTime = msgDate;

    // Record response in history
    try {
      final smsId = DateTime.now().millisecondsSinceEpoch.toString();
      final historyItem = SmsHistoryItem(
        id: smsId,
        phone: sender,
        command: _lastSentCommand ?? '',
        response: body,
        timestamp: DateTime.now(),
        status: SmsHistoryStatus.received,
        moduleName: widget.moduleName,
      );
      SmsHistoryService.addToHistory(historyItem);
      if (_currentSmsId != null) {
        SmsHistoryService.updateStatus(
          _currentSmsId!,
          SmsHistoryStatus.received,
          response: body,
        );
      }
    } catch (e) {
      debugPrint('Erreur ajout historique SMS: $e');
    }

    if (!mounted) return;
    // Stocker la réponse pour l'index courant
    if (_currentCommandIndex != null) {
      setState(() {
        _commandResponses[_currentCommandIndex!] = body;
      });
    }
    // Mark current command as confirmed and continue sequence
    _handleCommandConfirmation();
  }

  Future<void> _checkForNewSms() async {
    if (!_isSequentialSending || !_isWaitingForResponse) return;

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty) {
        // Get the most recent message
        final lastMsg = messages.first;
        final msgDate = lastMsg.date;
        final msgBody = lastMsg.body ?? '';
        final msgAddress = lastMsg.address ?? '';

        debugPrint('=== POLLING SMS ===');
        debugPrint('Dernier SMS de: $msgAddress');
        debugPrint('Message: $msgBody');
        debugPrint('Date: $msgDate');

        // Process this as a potential incoming SMS (handler will filter)
        if (msgBody.isNotEmpty) {
          _handleIncomingSms(lastMsg);
        }
      }
    } catch (e) {
      debugPrint('Erreur polling SMS: $e');
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
    _refreshSequenceCommands();

    if (notify && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isDataValid ? Icons.check_circle : Icons.warning,
                color: AppTheme.c1,
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

  Future<void> _startSequentialSend() async {
    if (_isSending || _isSequentialSending) return;

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

    if (_selectedOperatorForSequential == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selectionnez un operateur'),
          backgroundColor: Color(0xFFFFA500),
        ),
      );
      return;
    }

    _attemptCount = 0;
    await _loadCommandProgressFromHistory();

    if (_nextCommandIndex >= _sequenceCommands.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les commandes ont deja ete envoyees'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
      return;
    }

    setState(() {
      _isSequentialSending = true;
    });

    await _sendCommandAtIndex(_nextCommandIndex);
  }

  Future<void> _sendCommandAtIndex(int index) async {
    if (index < 0 || index >= _sequenceCommands.length) return;

    final phone = _normalizePhone(_phoneController.text);
    final command = _sequenceCommands[index]['command'] ?? '';
    if (command.isEmpty) return;

    _attemptCount++;

    // Mémoriser la date du dernier SMS déjà présent dans la boîte de réception
    // pour ne pas confondre un ancien SMS avec la réponse GPS
    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    final lastInboxDate = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    setState(() {
      _isSending = true;
      _currentCommandIndex = index;
      _lastSentCommand = command;
      _lastSentPhone = phone;
      _lastSmsCheckTime = lastInboxDate;
      _isWaitingForResponse = true;
      _commandProgress[index] = _CommandProgress.sent;
    });

    try {
      await _sendDirectSmsWithResult(phone, command);
    } catch (e) {
      debugPrint('Erreur envoi SMS: $e');
    }

    if (!mounted) return;
    _startResponseTimer(index);
  }

  void _startResponseTimer(int index) {
    _responseTimer?.cancel();
    _responseTimer = Timer(Duration(seconds: _replyTimeoutS), () {
      if (!mounted) return;
      if (!_isSequentialSending || !_isWaitingForResponse) return;
      if (_currentCommandIndex != index) return;

      // Toujours répéter la commande en échec (sans revenir au début)
      if (_currentSmsId != null) {
        SmsHistoryService.updateStatus(_currentSmsId!, SmsHistoryStatus.failed);
      }
      setState(() {
        _commandProgress[index] = _CommandProgress.failed;
        _isWaitingForResponse = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pas de réponse cmd ${index + 1} – nouvel essai (tentative ${_attemptCount + 1})…'),
          backgroundColor: Colors.orange.withOpacity(0.85),
          duration: const Duration(seconds: 3),
        ),
      );

      // Répéter la même commande (pas la suivante, pas le début)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _isSequentialSending) _sendCommandAtIndex(index);
      });
    });
  }

  void _handleCommandConfirmation() {
    if (_currentCommandIndex == null) return;

    _responseTimer?.cancel();
    _isWaitingForResponse = false;

    final index = _currentCommandIndex!;
    setState(() {
      _commandProgress[index] = _CommandProgress.confirmed;
      _nextCommandIndex = _commandProgress.indexWhere(
        (p) => p != _CommandProgress.confirmed,
      );
      if (_nextCommandIndex < 0) {
        _nextCommandIndex = _sequenceCommands.length;
      }
    });

    if (!_isSequentialSending) return;

    if (_nextCommandIndex >= _sequenceCommands.length) {
      _finishSequence();
      return;
    }

    // 800ms entre commandes pour éviter surcharge SMS
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _isSequentialSending) _sendCommandAtIndex(_nextCommandIndex);
    });
  }

  void _finishSequence() {
    setState(() {
      _isSending = false;
      _isSequentialSending = false;
      _isWaitingForResponse = false;
      _currentCommandIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les commandes confirmées ✓'),
        backgroundColor: Color(0xFF2ECC71),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _stopSequenceWithMessage(String message) {
    _responseTimer?.cancel();

    setState(() {
      _isSending = false;
      _isSequentialSending = false;
      _isWaitingForResponse = false;
      if (_currentCommandIndex != null) {
        _commandProgress[_currentCommandIndex!] = _CommandProgress.failed;
        _nextCommandIndex = _currentCommandIndex!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.transparent,
      ),
    );
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
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.c1, size: 28),
            SizedBox(width: 10),
            Text(
              'Détails du Module',
              style: TextStyle(color: AppTheme.c1, fontSize: 18),
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
            child: const Text('Fermer', style: TextStyle(color: AppTheme.c2)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.c2,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(
                color: AppTheme.c1,
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardBlue(radius: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConfigTab(),
                        const SizedBox(height: 20),
                        Divider(
                            color: AppTheme.c2.withOpacity(0.7), thickness: 1),
                        const SizedBox(height: 20),
                        _buildTestCommandsTab(),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Barre de statut compacte (visible uniquement pendant l'envoi) ──
              if (_isSequentialSending || _isWaitingForResponse)
                _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  // Barre de statut compacte affichée en bas pendant l'envoi
  Widget _buildStatusBar() {
    final confirmed =
        _commandProgress.where((p) => p == _CommandProgress.confirmed).length;
    final total = _sequenceCommands.length;
    final cmd = _currentCommandIndex != null &&
            _currentCommandIndex! < _sequenceCommands.length
        ? (_sequenceCommands[_currentCommandIndex!]['command'] ?? '')
        : '';

    Color barColor;
    IconData barIcon;
    String barText;

    if (_isWaitingForResponse) {
      barColor = const Color(0xFF3498DB);
      barIcon = Icons.hourglass_top;
      barText = 'Attente réponse GPS…  [$confirmed/$total]  →  $cmd';
    } else {
      barColor = const Color(0xFF48C9B0);
      barIcon = Icons.send;
      barText = 'Envoi en cours…  [$confirmed/$total]';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: barColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              value: total > 0 ? confirmed / total : null,
            ),
          ),
          const SizedBox(width: 10),
          Icon(barIcon, color: AppTheme.c1, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              barText,
              style: const TextStyle(
                color: AppTheme.c1,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
            backgroundColor: Colors.transparent,
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
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.signal_cellular_alt, size: 40),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            operator.name.isNotEmpty
                ? (operator.name[0].toUpperCase() + operator.name.substring(1))
                : operator.name,
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
            icon: Icon(
              Icons.info_outline,
              color: AppTheme.c1,
              size: 22,
            ),
            tooltip: 'Voir les details du module',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(8),
            ),
          ),
        if (_examples.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardBlue(radius: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        _moduleAsset(_equipmentController.text),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.memory,
                            color: AppTheme.c2, size: 40),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.devices, color: AppTheme.c1, size: 20),
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
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.numbers, color: Colors.white60, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SN: ${_serialController.text.isNotEmpty ? _serialController.text : (_examples[_selectedExampleIndex]['SerialNumber'] ?? 'N/A')}',
                        style:
                            const TextStyle(fontSize: 12, color: AppTheme.c2),
                      ),
                    ),
                  ],
                ),
                if (_simController.text.isNotEmpty ||
                    (_examples[_selectedExampleIndex]['SIMCardNumber'] ?? '')
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.sim_card,
                          color: Colors.white60, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SIM: ${_simController.text.isNotEmpty ? _simController.text : (_examples[_selectedExampleIndex]['SIMCardNumber'] ?? 'N/A')}',
                          style:
                              const TextStyle(fontSize: 12, color: AppTheme.c2),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedOperatorForSequential = MobileOperator.telecom;
                      Config.setSelectedOperator(MobileOperator.telecom);
                      _refreshSequenceCommands();
                    });
                    await Config.saveConfig();
                    if (!mounted) return;
                    _loadCommandProgressFromHistory();
                  },
                  child: Opacity(
                    opacity:
                        _selectedOperatorForSequential == MobileOperator.telecom
                            ? 1.0
                            : 0.45,
                    child: Image.asset(
                      Config.operatorImages[MobileOperator.telecom]!,
                      width: 56,
                      height: 56,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedOperatorForSequential = MobileOperator.orange;
                      Config.setSelectedOperator(MobileOperator.orange);
                      _refreshSequenceCommands();
                    });
                    await Config.saveConfig();
                    if (!mounted) return;
                    _loadCommandProgressFromHistory();
                  },
                  child: Opacity(
                    opacity:
                        _selectedOperatorForSequential == MobileOperator.orange
                            ? 1.0
                            : 0.45,
                    child: Image.asset(
                      Config.operatorImages[MobileOperator.orange]!,
                      width: 56,
                      height: 56,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedOperatorForSequential = MobileOperator.ooredoo;
                      Config.setSelectedOperator(MobileOperator.ooredoo);
                      _refreshSequenceCommands();
                    });
                    await Config.saveConfig();
                    if (!mounted) return;
                    _loadCommandProgressFromHistory();
                  },
                  child: Opacity(
                    opacity:
                        _selectedOperatorForSequential == MobileOperator.ooredoo
                            ? 1.0
                            : 0.45,
                    child: Image.asset(
                      Config.operatorImages[MobileOperator.ooredoo]!,
                      width: 56,
                      height: 56,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Configuration commands list with status
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sequenceCommands.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final cmd = _sequenceCommands[index];
            final progress = _commandProgress[index];
            final isCurrent = _currentCommandIndex == index;

            Color statusColor;
            IconData statusIcon;
            String statusText;

            switch (progress) {
              case _CommandProgress.confirmed:
                statusColor = const Color(0xFF2ECC71);
                statusIcon = Icons.check_circle;
                statusText = 'Confirmée';
                break;
              case _CommandProgress.sent:
                statusColor = const Color(0xFF3498DB);
                statusIcon = Icons.send;
                statusText = 'Envoyée';
                break;
              case _CommandProgress.failed:
                statusColor = const Color(0xFFDC143C);
                statusIcon = Icons.error;
                statusText = 'Échec';
                break;
              case _CommandProgress.pending:
                statusColor = Colors.white38;
                statusIcon = Icons.hourglass_empty;
                statusText = 'En attente';
                break;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(isCurrent ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cmd['command'] ?? '',
                          style: TextStyle(
                            color: AppTheme.c1,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cmd['description'] ?? '',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                        if (_commandResponses.containsKey(index)) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sms, color: statusColor, size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _commandResponses[index]!,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Envoyer button to send commands sequentially
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : () async => _startSequentialSend(),
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.c1,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(
              _isSending ? 'Envoi en cours...' : 'Envoyer les commandes',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.btnDark,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Send SMS and return true if sent successfully, false otherwise
  Future<bool> _sendDirectSmsWithResult(String phone, String message) async {
    Timer? fallbackTimer;
    try {
      // Create SMS ID and add to history immediately
      final smsId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentSmsId = smsId;
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

      final completer = Completer<bool>();
      bool sentHandled = false;

      void markSent({bool optimistic = false}) {
        if (sentHandled) return;
        sentHandled = true;
        SmsHistoryService.updateStatus(smsId, SmsHistoryStatus.sent);
        if (!completer.isCompleted) completer.complete(true);
      }

      fallbackTimer = Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          markSent(optimistic: true);
        }
      });

      await _telephony.sendSms(
        to: phone,
        message: message,
        statusListener: (SendStatus status) {
          if (!mounted) return;

          if (status == SendStatus.SENT) {
            markSent();
          } else if (status == SendStatus.DELIVERED) {
            markSent();
            SmsHistoryService.updateStatus(smsId, SmsHistoryStatus.delivered);
          }
        },
      );

      final result = await completer.future;
      fallbackTimer.cancel();
      return result;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      fallbackTimer?.cancel();
      if (_currentSmsId != null) {
        SmsHistoryService.updateStatus(_currentSmsId!, SmsHistoryStatus.sent);
      }
      if (!mounted) return true;
      return true;
    }
  }

  String _moduleAsset(String eq) {
    final n = eq.toLowerCase().replaceAll(' ', '');
    if (n.contains('gv300can') ||
        n.contains('easycantrace') ||
        n.contains('easycan')) return 'assets/gv300can-gps.jpg.jpeg';
    if (n.contains('et7') ||
        (n.contains('easytrace') && (n.contains('vii') || n.contains('7'))))
      return 'assets/ET7.jpeg';
    return 'assets/MT02S-200.jpg';
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: AppTheme.cardBlue(radius: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.c2),
          hintStyle: TextStyle(color: AppTheme.c2.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppTheme.c2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
