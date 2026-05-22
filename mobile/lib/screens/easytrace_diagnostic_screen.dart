import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:telephony/telephony.dart';
import '../services/sms_history_service.dart';
import '../models/sms_history.dart';
import '../services/gps_device_service.dart';
import 'position_map_screen.dart';

enum _StepStatus { pending, running, ok, warning, failed }

class _DiagStep {
  final String label;
  final String command;
  _StepStatus status;
  String? response;
  bool visible;

  _DiagStep({
    required this.label,
    required this.command,
    this.status = _StepStatus.pending,
    this.response,
    this.visible = true,
  });
}

class EasyTraceDiagnosticScreen extends StatefulWidget {
  final String moduleName;
  final String phoneNumber;
  final String? equipmentType;

  const EasyTraceDiagnosticScreen({
    super.key,
    required this.moduleName,
    required this.phoneNumber,
    this.equipmentType,
  });

  @override
  State<EasyTraceDiagnosticScreen> createState() =>
      _EasyTraceDiagnosticScreenState();
}

class _EasyTraceDiagnosticScreenState extends State<EasyTraceDiagnosticScreen> {
  final Telephony _telephony = Telephony.instance;

  bool _diagRunning = false;
  String _diagStep = '';
  String? _diagImei;
  Timer? _diagTimer;
  bool _diagWaiting = false;
  int? _lastSmsCheckTime;
  String? _lastSentPhone;
  Timer? _pollingTimer;
  int _retryCount = 0; // tentatives par étape

  late List<_DiagStep> _steps;

  // ── GV300CAN manual commands ──
  bool _gvCmdWaiting = false;
  String? _gvCmdSent;
  String? _gvCmdResponse;
  int? _gvLastSmsTime;
  Timer? _gvCmdTimer;
  Timer? _gvPollTimer;

  bool get _isGv300can {
    final eq = (widget.equipmentType ?? '').toLowerCase().replaceAll(' ', '');
    return eq.contains('gv300can') ||
        eq.contains('easycan') ||
        eq.contains('easycantrace');
  }

  List<_DiagStep> get _visibleSteps => _steps.where((s) => s.visible).toList();

  int get _okCount =>
      _visibleSteps.where((s) => s.status == _StepStatus.ok).length;
  int get _warnCount =>
      _visibleSteps.where((s) => s.status == _StepStatus.warning).length;
  int get _failCount =>
      _visibleSteps.where((s) => s.status == _StepStatus.failed).length;

  @override
  void initState() {
    super.initState();
    _initSteps();
    _startPolling();
  }

  void _initSteps() {
    _steps = [
      _DiagStep(label: 'IMEI / IP / Online', command: '*11*4#'),
      _DiagStep(
          label: 'Restauration IMEI', command: '*77*6*IMEI#', visible: false),
      _DiagStep(label: 'Contact / Fuel / Alim', command: 'STATUS#'),
      _DiagStep(label: 'Redémarrage module', command: 'RESET#', visible: false),
      _DiagStep(label: 'Heure UTC', command: 'UTC#'),
      _DiagStep(label: 'Correction UTC', command: 'UTC,0#', visible: false),
      _DiagStep(label: 'Protocole GPRS', command: 'GPRSSET#'),
      _DiagStep(
          label: 'Correction protocole',
          command: 'PROTOCOL,3,1#',
          visible: false),
      _DiagStep(label: 'Heartbeat config', command: 'HC#'),
      _DiagStep(
          label: 'Correction heartbeat',
          command: 'HC,60,7200,7200#',
          visible: false),
      _DiagStep(label: 'Angle virage', command: 'CORNER#'),
      _DiagStep(
          label: 'Correction angle virage',
          command: 'CORNER,20#',
          visible: false),
    ];
  }

  _DiagStep _step(String cmd) => _steps.firstWhere((s) => s.command == cmd);

  /// Retourne le SerialNumber API correspondant à _diagImei parmi les modules EasyTraceX.
  /// Si _diagImei correspond → retourne ce SerialNumber (IMEI OK).
  /// Si _diagImei absent/inconnu → retourne le premier SerialNumber EasyTraceX trouvé.
  Future<String?> _fetchApiImei() async {
    try {
      final devices = await GpsDeviceService.fetchDevices();
      final etxDevices = devices
          .where((d) =>
              d.equipmentType.toLowerCase().contains('easytrace') ||
              d.equipmentType.toLowerCase().contains('etx'))
          .toList();
      if (etxDevices.isEmpty) return null;
      // Chercher correspondance exacte avec l'IMEI détecté
      for (final d in etxDevices) {
        if (d.serialNumber.isNotEmpty && d.serialNumber == _diagImei)
          return d.serialNumber;
      }
      // Pas de correspondance → retourner le premier SerialNumber EasyTraceX
      return etxDevices.first.serialNumber.isNotEmpty
          ? etxDevices.first.serialNumber
          : null;
    } catch (_) {}
    return null;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollSms());
  }

  Future<void> _pollSms() async {
    if (!_diagWaiting) return;
    try {
      final msgs = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      if (msgs.isEmpty) return;
      final m = msgs.first;
      final date = m.date ?? 0;
      final body = m.body ?? '';
      if (body.isEmpty || date <= (_lastSmsCheckTime ?? 0)) return;
      final sender = m.address ?? '';
      if (_lastSentPhone != null && !_senderMatches(sender, _lastSentPhone!))
        return;
      // Stopper l'attente AVANT de traiter pour éviter double-déclenchement
      _lastSmsCheckTime = date;
      _diagTimer?.cancel();
      _diagWaiting = false;
      await _diagHandleResponse(body);
    } catch (_) {}
  }

  bool _senderMatches(String sender, String expected) {
    final s = sender.replaceAll(RegExp(r'[^0-9]'), '');
    final e = expected.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty || e.isEmpty) return true;
    return s.endsWith(e) || e.endsWith(s);
  }

  String _normalizePhone(String input) {
    final t = input.trim();
    if (t.startsWith('+'))
      return '+${t.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    return t.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _setStep(String cmd, _StepStatus status,
      {String? response, bool? visible}) {
    if (!mounted) return;
    setState(() {
      final s = _step(cmd);
      s.status = status;
      if (response != null) s.response = response;
      if (visible != null) s.visible = visible;
    });
  }

  Future<void> _runDiagnostic() async {
    if (_diagRunning) return;
    final phone = _normalizePhone(widget.phoneNumber);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Numéro de téléphone manquant'),
        backgroundColor: Color(0xFFDC143C),
      ));
      return;
    }
    setState(() {
      _diagRunning = true;
      _diagImei = null;
      _diagStep = 'check_imei';
      _retryCount = 0;
      for (final s in _steps) {
        if (s.status == _StepStatus.failed || s.status == _StepStatus.running) {
          s.status = _StepStatus.pending;
          s.response = null;
        }
      }
      _step('*77*6*IMEI#').visible = false;
      _step('RESET#').visible = false;
      _step('UTC,0#').visible = false;
      _step('PROTOCOL,3,1#').visible = false;
      _step('HC,60,7200,7200#').visible = false;
      _step('CORNER,20#').visible = false;
    });
    await _diagSendAndWait(phone, '*11*4#');
  }

  Future<void> _diagSendAndWait(String phone, String cmdKey) async {
    _lastSentPhone = phone;

    // Résoudre la commande réelle (IMEI dynamique)
    final resolvedCmd =
        cmdKey == '*77*6*IMEI#' ? '*77*6*${_diagImei ?? ''}#' : cmdKey;

    // Lire la date du dernier SMS AVANT envoi
    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _lastSmsCheckTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    _setStep(cmdKey, _StepStatus.running);
    setState(() {
      _diagWaiting = true;
      _retryCount = 0; // reset compteur à chaque nouvelle commande
    });

    await _sendSms(phone, resolvedCmd);

    _diagTimer?.cancel();
    _diagTimer = Timer(const Duration(seconds: 60), () async {
      if (!mounted || !_diagWaiting) return;
      _diagWaiting = false;
      _setStep(cmdKey, _StepStatus.failed,
          response: 'Timeout 60s — pas de réponse');
      await _diagHandleTimeout(phone, cmdKey);
    });
  }

  Future<void> _sendSms(String phone, String message) async {
    try {
      final smsId = DateTime.now().millisecondsSinceEpoch.toString();
      await SmsHistoryService.addToHistory(SmsHistoryItem(
        id: smsId,
        phone: phone,
        command: message,
        response: null,
        timestamp: DateTime.now(),
        status: SmsHistoryStatus.pending,
        moduleName: widget.moduleName,
      ));
      await _telephony.sendSms(
        to: phone,
        message: message,
        statusListener: (SendStatus s) {
          if (s == SendStatus.SENT || s == SendStatus.DELIVERED) {
            SmsHistoryService.updateStatus(smsId, SmsHistoryStatus.sent);
          }
        },
      );
    } catch (e) {
      debugPrint('SMS send error: $e');
    }
  }

  Future<void> _diagHandleResponse(String body) async {
    if (!mounted) return;
    final phone = _lastSentPhone!;
    switch (_diagStep) {
      // ── Étape 1 : *114# ─────────────────────────────────────────────────────
      case 'check_imei':
        final imeiMatch = RegExp(r'\b(\d{15})\b').firstMatch(body);
        if (imeiMatch != null) _diagImei = imeiMatch.group(1);
        final imeiOk = _diagImei != null && _diagImei != '000000000000000';
        _setStep('*11*4#', imeiOk ? _StepStatus.ok : _StepStatus.warning,
            response: body);

        if (!imeiOk) {
          final apiImei = await _fetchApiImei();
          if (apiImei != null) {
            _diagImei = apiImei;
            setState(() {
              _step('*77*6*IMEI#').visible = true;
              _diagStep = 'restore_imei';
            });
            await _diagSendAndWait(phone, '*77*6*IMEI#');
          } else {
            _setStep('*77*6*IMEI#', _StepStatus.failed,
                response: 'IMEI introuvable dans l\'API', visible: true);
            _diagFinish(success: false);
          }
        } else {
          final apiImei = await _fetchApiImei();
          if (apiImei != null && apiImei != _diagImei) {
            _diagImei = apiImei;
            setState(() {
              _step('*77*6*IMEI#').visible = true;
              _diagStep = 'restore_imei';
            });
            await _diagSendAndWait(phone, '*77*6*IMEI#');
          } else {
            setState(() => _diagStep = 'status');
            await _diagSendAndWait(phone, 'STATUS#');
          }
        }
        break;

      // ── Étape 2 (conditionnelle) : *77*6*IMEI# ──────────────────────────────
      case 'restore_imei':
        _setStep('*77*6*IMEI#', _StepStatus.ok, response: body);
        setState(() => _diagStep = 'status');
        await _diagSendAndWait(phone, 'STATUS#');
        break;

      // ── Étape 3 : STATUS# ───────────────────────────────────────────────────
      case 'status':
        final hasFailed = body.toLowerCase().contains('failed');
        _setStep('STATUS#', hasFailed ? _StepStatus.warning : _StepStatus.ok,
            response: body);
        if (hasFailed) {
          setState(() {
            _step('RESET#').visible = true;
            _diagStep = 'reset';
          });
          _setStep('RESET#', _StepStatus.running);
          await _sendSms(phone, 'RESET#');
          _setStep('RESET#', _StepStatus.ok,
              response: 'RESET# envoyé — attente 30s...');
          await Future.delayed(const Duration(seconds: 30));
          if (!mounted) return;
        }
        setState(() => _diagStep = 'utc');
        await _diagSendAndWait(phone, 'UTC#');
        break;

      // ── Étape 4 : UTC# ──────────────────────────────────────────────────────
      case 'utc':
        final utcOk = body.toUpperCase().contains('UTC:0');
        _setStep('UTC#', utcOk ? _StepStatus.ok : _StepStatus.warning,
            response: body);
        if (!utcOk) {
          setState(() {
            _step('UTC,0#').visible = true;
            _diagStep = 'utc_fix';
          });
          await _diagSendAndWait(phone, 'UTC,0#');
        } else {
          setState(() => _diagStep = 'gprsset');
          await _diagSendAndWait(phone, 'GPRSSET#');
        }
        break;

      // ── Étape 4b (conditionnelle) : UTC,0# ──────────────────────────────────
      case 'utc_fix':
        _setStep('UTC,0#', _StepStatus.ok, response: body);
        setState(() => _diagStep = 'gprsset');
        await _diagSendAndWait(phone, 'GPRSSET#');
        break;

      // ── Étape 5 : GPRSSET# ──────────────────────────────────────────────────
      case 'gprsset':
        final protocolOk =
            RegExp(r'PROTOCOL\s*:\s*3\s*,\s*1', caseSensitive: false)
                .hasMatch(body);
        _setStep('GPRSSET#', protocolOk ? _StepStatus.ok : _StepStatus.warning,
            response: body);
        if (!protocolOk) {
          setState(() {
            _step('PROTOCOL,3,1#').visible = true;
            _diagStep = 'protocol_fix';
          });
          await _diagSendAndWait(phone, 'PROTOCOL,3,1#');
        } else {
          setState(() => _diagStep = 'hc');
          await _diagSendAndWait(phone, 'HC#');
        }
        break;

      // ── Étape 5b (conditionnelle) : PROTOCOL,3,1# ───────────────────────────
      case 'protocol_fix':
        _setStep('PROTOCOL,3,1#', _StepStatus.ok, response: body);
        setState(() => _diagStep = 'hc');
        await _diagSendAndWait(phone, 'HC#');
        break;

      // ── Étape 6 : HC# ───────────────────────────────────────────────────────
      case 'hc':
        final hcOk =
            RegExp(r'HC\s*:\s*60\s*,\s*7200\s*,\s*7200', caseSensitive: false)
                .hasMatch(body);
        _setStep('HC#', hcOk ? _StepStatus.ok : _StepStatus.warning,
            response: body);
        if (!hcOk) {
          setState(() {
            _step('HC,60,7200,7200#').visible = true;
            _diagStep = 'hc_fix';
          });
          await _diagSendAndWait(phone, 'HC,60,7200,7200#');
        } else {
          setState(() => _diagStep = 'corner');
          await _diagSendAndWait(phone, 'CORNER#');
        }
        break;

      // ── Étape 6b (conditionnelle) : HC,60,7200,7200# ────────────────────────
      case 'hc_fix':
        _setStep('HC,60,7200,7200#', _StepStatus.ok, response: body);
        setState(() => _diagStep = 'corner');
        await _diagSendAndWait(phone, 'CORNER#');
        break;

      // ── Étape 7 : CORNER# ───────────────────────────────────────────────────
      case 'corner':
        final cornerOk =
            RegExp(r'CORNER\s*:\s*20', caseSensitive: false).hasMatch(body);
        _setStep('CORNER#', cornerOk ? _StepStatus.ok : _StepStatus.warning,
            response: body);
        if (!cornerOk) {
          setState(() {
            _step('CORNER,20#').visible = true;
            _diagStep = 'corner_fix';
          });
          await _diagSendAndWait(phone, 'CORNER,20#');
        } else {
          _diagFinish(success: true);
        }
        break;

      // ── Étape 7b (conditionnelle) : CORNER,20# ──────────────────────────────
      case 'corner_fix':
        _setStep('CORNER,20#', _StepStatus.ok, response: body);
        _diagFinish(success: true);
        break;

      default:
        _diagFinish(success: true);
    }
  }

  Future<void> _diagHandleTimeout(String phone, String cmdKey) async {
    final failedCmd = cmdKey;

    if (_retryCount == 0) {
      // 1ère tentative : réessayer la même commande
      _retryCount++;
      if (failedCmd.isNotEmpty) {
        _setStep(failedCmd, _StepStatus.running,
            response: '🔄 Nouvel essai...');
        await _diagSendAndWait(phone, failedCmd);
      } else {
        _diagFinish(success: false);
      }
    } else if (_retryCount == 1) {
      // 2ème tentative : RESET# puis réessayer
      _retryCount++;
      if (failedCmd.isNotEmpty) {
        _setStep(failedCmd, _StepStatus.running,
            response: '⏳ RESET# envoyé — attente 30s...');
        await _diagSendReset(phone, nextStep: _diagStep, nextCmd: failedCmd);
      } else {
        _diagFinish(success: false);
      }
    } else {
      // Tous les essais épuisés
      if (failedCmd.isNotEmpty) {
        _setStep(failedCmd, _StepStatus.failed,
            response: 'Aucune réponse après 3 essais');
      }
      _diagFinish(success: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.c1, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Module ne répond pas — Répéter ultérieurement')),
            ],
          ),
          backgroundColor: Color(0xFFDC143C),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _diagSendReset(String phone,
      {required String nextStep, required String nextCmd}) async {
    await _sendSms(phone, 'RESET#');
    if (!mounted) return;
    setState(() => _diagStep = nextStep);
    _setStep(nextCmd, _StepStatus.running,
        response: '⏳ Attente 30s redémarrage...');
    await Future.delayed(const Duration(seconds: 30));
    if (!mounted) return;
    _retryCount = 0;
    await _diagSendAndWait(phone, nextCmd);
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: const Text('Vider l\'historique',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Cette action enverra CLR,BLIND# au module et effacera le cache. Continuer ?',
            style: TextStyle(color: AppTheme.c2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: AppTheme.c2.withOpacity(0.7))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC143C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final phone = _normalizePhone(widget.phoneNumber);
    if (phone.isEmpty) return;
    await _sendSms(phone, 'CLR,BLIND#');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('CLR,BLIND# envoyé — historique vidé'),
      backgroundColor: Color(0xFF2ECC71),
      duration: Duration(seconds: 3),
    ));
  }

  void _diagFinish({required bool success}) {
    if (!mounted) return;
    setState(() => _diagRunning = false);
  }

  // ── GV300CAN manual send ──────────────────────────────────────────────────

  Future<void> _sendGvCmd(String cmd,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final phone = _normalizePhone(widget.phoneNumber);
    if (phone.isEmpty) return;

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _gvLastSmsTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    setState(() {
      _gvCmdWaiting = true;
      _gvCmdSent = cmd;
      _gvCmdResponse = null;
    });

    await _sendSms(phone, cmd);

    _gvCmdTimer?.cancel();
    _gvPollTimer?.cancel();

    // Pour power-off et reboot : pas de réponse attendue
    final noReply = cmd.contains(',5,,') || cmd.contains(',3,,');
    if (noReply) {
      setState(() {
        _gvCmdWaiting = false;
        _gvCmdResponse = 'Commande envoyée';
      });
      return;
    }

    _gvCmdTimer = Timer(timeout, () {
      if (!mounted || !_gvCmdWaiting) return;
      setState(() {
        _gvCmdWaiting = false;
        _gvCmdResponse = 'Timeout — pas de réponse';
      });
      _gvPollTimer?.cancel();
    });

    _gvPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_gvCmdWaiting) {
        _gvPollTimer?.cancel();
        return;
      }
      try {
        final msgs = await _telephony.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        );
        if (msgs.isEmpty) return;
        final m = msgs.first;
        final date = m.date ?? 0;
        final body = m.body ?? '';
        if (body.isEmpty || date <= (_gvLastSmsTime ?? 0)) return;
        _gvLastSmsTime = date;
        _gvCmdTimer?.cancel();
        _gvPollTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _gvCmdWaiting = false;
          _gvCmdResponse = body;
        });
        // Si c'est une réponse position → ouvrir la carte
        if (cmd.contains(',0,,3,')) {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PositionMapScreen(
                    moduleName: widget.moduleName, rawSms: body),
              ));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _diagTimer?.cancel();
    _pollingTimer?.cancel();
    _gvCmdTimer?.cancel();
    _gvPollTimer?.cancel();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    // GV300CAN : afficher uniquement le panneau de commandes
    if (_isGv300can) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Diagnostic EasyCanTrace',
                  style: TextStyle(fontSize: 15)),
              Text(widget.moduleName,
                  style: const TextStyle(fontSize: 11, color: AppTheme.c2)),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Info module ──
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.cardBlue(radius: 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/gv300can-gps.jpg.jpeg',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.memory, color: AppTheme.c3, size: 44)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.moduleName,
                              style: const TextStyle(
                                  color: AppTheme.c1,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text('SIM: ${widget.phoneNumber}',
                              style: const TextStyle(
                                  color: AppTheme.c2, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                  child: SingleChildScrollView(
                child: _buildGvCommandsPanel(),
              )),
            ],
          ),
        ),
      );
    }

    // EasyTraceX : diagnostic complet
    final total = _visibleSteps.length;
    final done = _okCount + _warnCount + _failCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostic EasyTraceX', style: TextStyle(fontSize: 15)),
            Text(widget.moduleName,
                style: const TextStyle(fontSize: 11, color: AppTheme.c2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Vider historique',
            onPressed: _diagRunning ? null : _confirmClearHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Info module ──
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardBlue(radius: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(_moduleAsset(widget.equipmentType ?? ''),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.memory, color: AppTheme.c3, size: 44)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.moduleName,
                            style: const TextStyle(
                                color: AppTheme.c1,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('SIM: ${widget.phoneNumber}',
                            style: const TextStyle(
                                color: AppTheme.c2, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_diagRunning)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.skyBottom),
                    ),
                ],
              ),
            ),
            // ── Barre progression + badges ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? done / total : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        _failCount > 0
                            ? Colors.red
                            : _warnCount > 0
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$done/$total étapes',
                          style: const TextStyle(
                              color: AppTheme.c2, fontSize: 11)),
                      Row(children: [
                        _badge('✓', _okCount, Colors.green),
                        const SizedBox(width: 4),
                        _badge('⚠', _warnCount, Colors.orange),
                        const SizedBox(width: 4),
                        _badge('✗', _failCount, Colors.red),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Liste étapes ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _visibleSteps.map(_buildStepCard).toList(),
              ),
            ),
            // ── Bouton lancer ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _diagRunning ? null : _runDiagnostic,
                  icon: _diagRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_diagRunning
                      ? 'Diagnostic en cours...'
                      : 'Lancer le diagnostic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.btnDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGvCommandsPanel() {
    final cmds = [
      (
        label: 'Niveau batterie',
        subtitle: 'Batterie + état chargeur',
        icon: Icons.battery_charging_full,
        color: const Color(0xFFFFB347),
        cmd: r'AT+GTRTO=gv300can,9,,3,,,,FFFF$',
      ),
      (
        label: 'Redémarrer',
        subtitle: 'Reboot du terminal',
        icon: Icons.restart_alt,
        color: const Color(0xFF5DA5B3),
        cmd: r'AT+GTRTO=gv300can,3,,,,,,FFFF$',
      ),
      (
        label: 'Éteindre',
        subtitle: 'Power off',
        icon: Icons.power_settings_new,
        color: const Color(0xFFDC143C),
        cmd: r'AT+GTRTO=gv300can,5,,,,,,FFFF$',
      ),
      (
        label: 'Version firmware',
        subtitle: 'Informations firmware',
        icon: Icons.info_outline,
        color: const Color(0xFF9B59B6),
        cmd: r'AT+GTRTO=gv300can,2,,,,,,FFFF$',
      ),
    ];

    // Trouver la commande en cours d'exécution
    final activeCmd = _gvCmdSent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête section
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.terminal, color: AppTheme.skyBottom, size: 16),
              const SizedBox(width: 8),
              const Text('Commandes GV300CAN',
                  style: TextStyle(
                      color: AppTheme.c1,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              if (_gvCmdWaiting) ...[
                const SizedBox(width: 8),
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.skyBottom)),
              ],
            ]),
          ),
          // Commandes en style step cards
          ...cmds.map((c) {
            final isActive = activeCmd == c.cmd;
            final isWaiting = _gvCmdWaiting && isActive;
            final hasResponse = isActive && _gvCmdResponse != null;
            final color = c.color;
            return GestureDetector(
              onTap: _gvCmdWaiting ? null : () => _sendGvCmd(c.cmd),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(isActive ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withOpacity(isActive ? 0.5 : 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8)),
                        child: isWaiting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: color))
                            : Icon(c.icon, color: color, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label,
                                style: TextStyle(
                                    color: AppTheme.c1,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(c.subtitle,
                                style: TextStyle(
                                    color: AppTheme.c2, fontSize: 10)),
                          ],
                        ),
                      ),
                      if (isWaiting)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Attente...',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        )
                      else if (!_gvCmdWaiting)
                        Icon(Icons.send_rounded,
                            size: 14,
                            color: color.withOpacity(0.5)),
                    ]),
                    const SizedBox(height: 4),
                    Text(c.cmd,
                        style: const TextStyle(
                            color: AppTheme.c2,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                    // Réponse SMS
                    if (hasResponse) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.sms_outlined,
                                  size: 12, color: color),
                              const SizedBox(width: 4),
                              Text('Réponse SMS :',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 6),
                            SelectableText(
                              _gvCmdResponse!,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _badge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label $count',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStepCard(_DiagStep step) {
    Color c;
    IconData icon;
    switch (step.status) {
      case _StepStatus.ok:
        c = Colors.green;
        icon = Icons.check_circle;
        break;
      case _StepStatus.warning:
        c = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case _StepStatus.failed:
        c = Colors.red;
        icon = Icons.cancel;
        break;
      case _StepStatus.running:
        c = AppTheme.skyBottom;
        icon = Icons.hourglass_top;
        break;
      default:
        c = Colors.white24;
        icon = Icons.radio_button_unchecked;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: c.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8)),
                child: step.status == _StepStatus.running
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: c))
                    : Icon(icon, color: c, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.label,
                    style: const TextStyle(
                        color: AppTheme.c1,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(step.command,
              style: const TextStyle(
                  color: AppTheme.c2, fontSize: 10, fontFamily: 'monospace')),
          if (step.response != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.sms_outlined, size: 12, color: c),
                    const SizedBox(width: 4),
                    Text('Réponse SMS :',
                        style: TextStyle(
                            color: c,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  SelectableText(
                    step.response!,
                    style: TextStyle(
                        color: c,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
