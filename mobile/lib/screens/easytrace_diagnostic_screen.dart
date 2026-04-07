import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'package:telephony/telephony.dart';
import '../services/sms_history_service.dart';
import '../models/sms_history.dart';
import '../services/gps_device_service.dart';

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

  const EasyTraceDiagnosticScreen({
    super.key,
    required this.moduleName,
    required this.phoneNumber,
  });

  @override
  State<EasyTraceDiagnosticScreen> createState() =>
      _EasyTraceDiagnosticScreenState();
}

class _EasyTraceDiagnosticScreenState
    extends State<EasyTraceDiagnosticScreen> {
  final Telephony _telephony = Telephony.instance;

  bool _diagRunning = false;
  String _diagStep = '';
  String? _diagImei;
  Timer? _diagTimer;
  bool _diagWaiting = false;
  int? _lastSmsCheckTime;
  String? _lastSentPhone;
  Timer? _pollingTimer;
  int _retryCount = 0;  // tentatives par étape

  late List<_DiagStep> _steps;

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
      _DiagStep(label: 'IMEI / IP / Online',      command: '*11*4#'),
      _DiagStep(label: 'Restauration IMEI',        command: '*77*6*IMEI#', visible: false),
      _DiagStep(label: 'Contact / Fuel / Alim',    command: 'STATUS#'),
      _DiagStep(label: 'Redémarrage module',        command: 'RESET#', visible: false),
      _DiagStep(label: 'Heure UTC',                command: 'UTC#'),
      _DiagStep(label: 'Correction UTC',           command: 'UTC,0#', visible: false),
      _DiagStep(label: 'Protocole GPRS',           command: 'GPRSSET#'),
      _DiagStep(label: 'Correction protocole',     command: 'PROTOCOL,3,1#', visible: false),
      _DiagStep(label: 'Heartbeat config',         command: 'HC#'),
      _DiagStep(label: 'Correction heartbeat',     command: 'HC,60,7200,7200#', visible: false),
      _DiagStep(label: 'Angle virage',             command: 'CORNER#'),
      _DiagStep(label: 'Correction angle virage',  command: 'CORNER,20#', visible: false),
    ];
  }

  _DiagStep _step(String cmd) =>
      _steps.firstWhere((s) => s.command == cmd);

  /// Retourne le SerialNumber API correspondant à _diagImei parmi les modules EasyTraceX.
  /// Si _diagImei correspond → retourne ce SerialNumber (IMEI OK).
  /// Si _diagImei absent/inconnu → retourne le premier SerialNumber EasyTraceX trouvé.
  Future<String?> _fetchApiImei() async {
    try {
      final devices = await GpsDeviceService.fetchDevices();
      final etxDevices = devices.where((d) =>
          d.equipmentType.toLowerCase().contains('easytrace') ||
          d.equipmentType.toLowerCase().contains('etx')).toList();
      if (etxDevices.isEmpty) return null;
      // Chercher correspondance exacte avec l'IMEI détecté
      for (final d in etxDevices) {
        if (d.serialNumber.isNotEmpty && d.serialNumber == _diagImei) return d.serialNumber;
      }
      // Pas de correspondance → retourner le premier SerialNumber EasyTraceX
      return etxDevices.first.serialNumber.isNotEmpty ? etxDevices.first.serialNumber : null;
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
      if (_lastSentPhone != null && !_senderMatches(sender, _lastSentPhone!)) return;
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

  void _setStep(String cmd, _StepStatus status, {String? response, bool? visible}) {
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
    final resolvedCmd = cmdKey == '*77*6*IMEI#' ? '*77*6*${_diagImei ?? ''}#' : cmdKey;

    // Lire la date du dernier SMS AVANT envoi
    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _lastSmsCheckTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    _setStep(cmdKey, _StepStatus.running);
    setState(() {
      _diagWaiting = true;
      _retryCount = 0;  // reset compteur à chaque nouvelle commande
    });

    await _sendSms(phone, resolvedCmd);

    _diagTimer?.cancel();
    _diagTimer = Timer(const Duration(seconds: 60), () async {
      if (!mounted || !_diagWaiting) return;
      _diagWaiting = false;
      _setStep(cmdKey, _StepStatus.failed, response: 'Timeout 60s — pas de réponse');
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
        _setStep('*11*4#', imeiOk ? _StepStatus.ok : _StepStatus.warning, response: body);

        if (!imeiOk) {
          final apiImei = await _fetchApiImei();
          if (apiImei != null) {
            _diagImei = apiImei;
            setState(() { _step('*77*6*IMEI#').visible = true; _diagStep = 'restore_imei'; });
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
            setState(() { _step('*77*6*IMEI#').visible = true; _diagStep = 'restore_imei'; });
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
        _setStep('STATUS#', hasFailed ? _StepStatus.warning : _StepStatus.ok, response: body);
        if (hasFailed) {
          setState(() { _step('RESET#').visible = true; _diagStep = 'reset'; });
          _setStep('RESET#', _StepStatus.running);
          await _sendSms(phone, 'RESET#');
          _setStep('RESET#', _StepStatus.ok, response: 'RESET# envoyé — attente 30s...');
          await Future.delayed(const Duration(seconds: 30));
          if (!mounted) return;
        }
        setState(() => _diagStep = 'utc');
        await _diagSendAndWait(phone, 'UTC#');
        break;

      // ── Étape 4 : UTC# ──────────────────────────────────────────────────────
      case 'utc':
        final utcOk = body.toUpperCase().contains('UTC:0');
        _setStep('UTC#', utcOk ? _StepStatus.ok : _StepStatus.warning, response: body);
        if (!utcOk) {
          setState(() { _step('UTC,0#').visible = true; _diagStep = 'utc_fix'; });
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
        final protocolOk = RegExp(r'PROTOCOL\s*:\s*3\s*,\s*1',
            caseSensitive: false).hasMatch(body);
        _setStep('GPRSSET#', protocolOk ? _StepStatus.ok : _StepStatus.warning, response: body);
        if (!protocolOk) {
          setState(() { _step('PROTOCOL,3,1#').visible = true; _diagStep = 'protocol_fix'; });
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
        final hcOk = RegExp(r'HC\s*:\s*60\s*,\s*7200\s*,\s*7200',
            caseSensitive: false).hasMatch(body);
        _setStep('HC#', hcOk ? _StepStatus.ok : _StepStatus.warning, response: body);
        if (!hcOk) {
          setState(() { _step('HC,60,7200,7200#').visible = true; _diagStep = 'hc_fix'; });
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
        final cornerOk = RegExp(r'CORNER\s*:\s*20',
            caseSensitive: false).hasMatch(body);
        _setStep('CORNER#', cornerOk ? _StepStatus.ok : _StepStatus.warning, response: body);
        if (!cornerOk) {
          setState(() { _step('CORNER,20#').visible = true; _diagStep = 'corner_fix'; });
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
        _setStep(failedCmd, _StepStatus.running, response: '🔄 Nouvel essai...');
        await _diagSendAndWait(phone, failedCmd);
      } else {
        _diagFinish(success: false);
      }
    } else if (_retryCount == 1) {
      // 2ème tentative : RESET# puis réessayer
      _retryCount++;
      if (failedCmd.isNotEmpty) {
        _setStep(failedCmd, _StepStatus.running, response: '⏳ RESET# envoyé — attente 30s...');
        await _diagSendReset(phone, nextStep: _diagStep, nextCmd: failedCmd);
      } else {
        _diagFinish(success: false);
      }
    } else {
      // Tous les essais épuisés
      if (failedCmd.isNotEmpty) {
        _setStep(failedCmd, _StepStatus.failed, response: 'Aucune réponse après 3 essais');
      }
      _diagFinish(success: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.c1, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Module ne répond pas — Répéter ultérieurement')),
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
    _setStep(nextCmd, _StepStatus.running, response: '⏳ Attente 30s redémarrage...');
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
            child: Text('Annuler', style: TextStyle(color: AppTheme.c2.withOpacity(0.7))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC143C)),
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

  @override
  void dispose() {
    _diagTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostic EasyTraceX',
                style: TextStyle(fontSize: 16)),
            Text(widget.moduleName,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.c2)),
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
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModuleInfoCard(),
                const SizedBox(height: 16),
                SizedBox(
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
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Étapes du diagnostic',
                    style: TextStyle(
                        color: AppTheme.c1,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ..._visibleSteps.map(_buildStepCard),
                const SizedBox(height: 20),
                _buildDashboard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBlue(radius: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/MT02S-200.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.moduleName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: AppTheme.c2),
                    const SizedBox(width: 4),
                    Text(widget.phoneNumber,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.c2)),
                  ],
                ),
              ],
            ),
          ),
          if (_diagWaiting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF8E44AD)),
            ),
        ],
      ),
    );
  }

  Widget _buildStepCard(_DiagStep step) {
    Color iconColor;
    IconData icon;

    switch (step.status) {
      case _StepStatus.ok:
        iconColor = const Color(0xFF2ECC71);
        icon = Icons.check_circle;
        break;
      case _StepStatus.warning:
        iconColor = const Color(0xFFFFA500);
        icon = Icons.warning_amber_rounded;
        break;
      case _StepStatus.failed:
        iconColor = const Color(0xFFDC143C);
        icon = Icons.cancel;
        break;
      case _StepStatus.running:
        iconColor = const Color(0xFF3498DB);
        icon = Icons.hourglass_top;
        break;
      default:
        iconColor = Colors.white38;
        icon = Icons.radio_button_unchecked;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8)),
            child: step.status == _StepStatus.running
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: iconColor))
                : Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: const TextStyle(
                        color: AppTheme.c1,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(step.command,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                if (step.response != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      step.response!,
                      style: TextStyle(
                          color: iconColor,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final visible = _visibleSteps;
    final total = visible.length;
    final done = _okCount + _warnCount + _failCount;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBlue(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard diagnostic',
              style: TextStyle(
                  color: AppTheme.c1,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                _failCount > 0
                    ? const Color(0xFFDC143C)
                    : _warnCount > 0
                        ? const Color(0xFFFFA500)
                        : const Color(0xFF2ECC71),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$done / $total étapes traitées',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildCounter(
                      'OK', _okCount, const Color(0xFF2ECC71), Icons.check_circle)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildCounter('Avertissement', _warnCount,
                      const Color(0xFFFFA500), Icons.warning_amber_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildCounter(
                      'Échec', _failCount, const Color(0xFFDC143C), Icons.cancel)),
            ],
          ),
          if (done > 0 && !_diagRunning) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: (_failCount == 0 && _warnCount == 0)
                    ? const Color(0xFF2ECC71).withOpacity(0.15)
                    : _failCount > 0
                        ? const Color(0xFFDC143C).withOpacity(0.15)
                        : const Color(0xFFFFA500).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    (_failCount == 0 && _warnCount == 0)
                        ? Icons.check_circle
                        : _failCount > 0
                            ? Icons.error
                            : Icons.warning,
                    color: (_failCount == 0 && _warnCount == 0)
                        ? const Color(0xFF2ECC71)
                        : _failCount > 0
                            ? const Color(0xFFDC143C)
                            : const Color(0xFFFFA500),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_failCount == 0 && _warnCount == 0)
                          ? 'Module opérationnel — tous les tests OK'
                          : _failCount > 0
                              ? 'Problème détecté — vérification manuelle requise'
                              : 'Module fonctionnel avec avertissements',
                      style: const TextStyle(
                          color: AppTheme.c1, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounter(
      String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}






