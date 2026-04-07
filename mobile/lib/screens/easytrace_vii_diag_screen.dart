import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../services/sms_history_service.dart';
import '../models/sms_history.dart';
import '../utils/app_theme.dart';

enum _StepStatus { pending, running, ok, warning, failed }

class _DiagStep {
  final String label;
  final String queryCmd;
  final String fixCmd;
  final String resetCmd;
  final String expectedKey;
  _StepStatus status;
  String? response;
  String? note;
  DateTime? sentAt;

  _DiagStep({
    required this.label,
    required this.queryCmd,
    required this.fixCmd,
    required this.resetCmd,
    required this.expectedKey,
    this.status = _StepStatus.pending,
    this.response,
    this.note,
    this.sentAt,
  });
}

class EasyTraceVIIDiagScreen extends StatefulWidget {
  final String moduleName;
  final String phoneNumber;
  final String imei;
  final String password;

  const EasyTraceVIIDiagScreen({
    super.key,
    required this.moduleName,
    required this.phoneNumber,
    required this.imei,
    required this.password,
  });

  @override
  State<EasyTraceVIIDiagScreen> createState() => _EasyTraceVIIDiagScreenState();
}

class _EasyTraceVIIDiagScreenState extends State<EasyTraceVIIDiagScreen> {
  final Telephony _telephony = Telephony.instance;

  bool _running = false;
  bool _waiting = false;
  int? _currentStep;
  int? _lastSmsTime;
  String? _lastPhone;
  Timer? _stepTimer;
  Timer? _pollTimer;
  Timer? _uiTimer;
  int _retryCount = 0;
  int _gpsResets = 0;
  int _boitierResets = 0;
  int _gsmResets = 0;

  // Timeout 50 minutes pour EasyTraceVII
  static const _timeoutDuration = Duration(minutes: 50);

  late List<_DiagStep> _steps;

  String get _imei => widget.imei;
  String get _pass => widget.password;
  String get _phone => widget.phoneNumber;

  @override
  void initState() {
    super.initState();
    _initSteps();
    _startPolling();
  }

  void _initSteps() {
    _steps = [
      _DiagStep(
        label: 'Password',
        queryCmd: '&&tunavpsw,Z13,?',
        fixCmd: '',
        resetCmd: '',
        expectedKey: 'Z13',
      ),
      _DiagStep(
        label: 'IP & Port',
        queryCmd: '&&$_imei,$_pass,Z39,?,?,?,?',
        fixCmd: '&&$_imei,$_pass,Z39,1,41.226.24.13,1200,1',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z39,1,41.226.24.13,1200,1',
      ),
      _DiagStep(
        label: 'Time Report',
        queryCmd: '&&$_imei,$_pass,Z31,?,?,?,?,?,?,?,?',
        fixCmd: '&&$_imei,$_pass,Z31,60,600,60,600,60,600,5,1',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z31,60,600,60,600,60,600,5,1',
      ),
      _DiagStep(
        label: 'Distance Report',
        queryCmd: '&&$_imei,$_pass,Z36,?,?,?,?',
        fixCmd: '&&$_imei,$_pass,Z36,0.7,3,3,1',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z36',
      ),
      _DiagStep(
        label: 'Angle Report',
        queryCmd: '&&$_imei,$_pass,Z37,?,?,?',
        fixCmd: '&&$_imei,$_pass,Z37,25,2,1',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z37,25,2,1',
      ),
      _DiagStep(
        label: 'Contact ON/OFF',
        queryCmd: '&&$_imei,$_pass,Z80,?,?',
        fixCmd: '&&$_imei,$_pass,Z80,1,0',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z80,1,0',
      ),
      _DiagStep(
        label: 'Lock GPS ACC off',
        queryCmd: '&&$_imei,$_pass,Z27,?,?',
        fixCmd: '&&$_imei,$_pass,Z27,1.0,0',
        resetCmd: '&&$_imei,$_pass,Y35',
        expectedKey: 'CFG:Z27,1.0,0',
      ),
    ];
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollSms());
    // Rafraîchir l'UI chaque seconde pour le compteur de temps
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_waiting && mounted) setState(() {});
    });
  }

  Future<void> _pollSms() async {
    if (!_waiting) return;
    try {
      final msgs = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      if (msgs.isEmpty) return;
      final m = msgs.first;
      final date = m.date ?? 0;
      final body = m.body ?? '';
      if (body.isEmpty || date <= (_lastSmsTime ?? 0)) return;
      final sender = m.address ?? '';
      if (_lastPhone != null && !_senderMatches(sender, _lastPhone!)) return;
      _lastSmsTime = date;
      _stepTimer?.cancel();
      _waiting = false;
      await _handleResponse(body);
    } catch (_) {}
  }

  bool _senderMatches(String s, String e) {
    final sn = s.replaceAll(RegExp(r'[^0-9]'), '');
    final en = e.replaceAll(RegExp(r'[^0-9]'), '');
    if (sn.isEmpty || en.isEmpty) return true;
    return sn.endsWith(en) || en.endsWith(sn);
  }

  String _normalize(String p) {
    final t = p.trim();
    if (t.startsWith('+')) return '+${t.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    return t.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _setStep(int i, _StepStatus s, {String? response, String? note}) {
    if (!mounted) return;
    setState(() {
      _steps[i].status = s;
      if (response != null) _steps[i].response = response;
      if (note != null) _steps[i].note = note;
      if (s == _StepStatus.running) _steps[i].sentAt = DateTime.now();
    });
  }

  Future<void> _run() async {
    if (_running) return;
    final phone = _normalize(_phone);
    if (phone.isEmpty) {
      _snack('Numéro de téléphone manquant', Colors.red);
      return;
    }
    setState(() {
      _running = true;
      _gpsResets = 0; _boitierResets = 0; _gsmResets = 0;
      for (final s in _steps) {
        s.status = _StepStatus.pending;
        s.response = null;
        s.note = null;
        s.sentAt = null;
      }
    });
    await _runStep(0, phone);
  }

  Future<void> _runStep(int i, String phone) async {
    if (i >= _steps.length) { _finish(); return; }
    setState(() => _currentStep = i);
    _setStep(i, _StepStatus.running);
    _retryCount = 0;
    await _sendAndWait(i, phone, _steps[i].queryCmd);
  }

  Future<void> _sendAndWait(int i, String phone, String cmd) async {
    _lastPhone = phone;
    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _lastSmsTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;
    setState(() { _waiting = true; _steps[i].sentAt = DateTime.now(); });
    await _sendSms(phone, cmd);
    _stepTimer?.cancel();
    // Timeout 50 minutes
    _stepTimer = Timer(_timeoutDuration, () async {
      if (!mounted || !_waiting) return;
      _waiting = false;
      await _handleTimeout(i, phone);
    });
  }

  Future<void> _sendSms(String phone, String msg) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await SmsHistoryService.addToHistory(SmsHistoryItem(
        id: id, phone: phone, command: msg, response: null,
        timestamp: DateTime.now(), status: SmsHistoryStatus.pending,
        moduleName: widget.moduleName,
      ));
      await _telephony.sendSms(
        to: phone, message: msg,
        statusListener: (s) {
          if (s == SendStatus.SENT || s == SendStatus.DELIVERED) {
            SmsHistoryService.updateStatus(id, SmsHistoryStatus.sent);
          }
        },
      );
    } catch (e) { debugPrint('SMS error: $e'); }
  }

  Future<void> _handleResponse(String body) async {
    if (!mounted) return;
    final i = _currentStep;
    if (i == null) return;
    final phone = _normalize(_phone);
    final step = _steps[i];

    // Afficher la réponse complète
    _setStep(i, _StepStatus.running, response: body);

    if (i == 0) {
      _setStep(i, _StepStatus.ok, response: body, note: 'Password lu ✓');
      await _runStep(i + 1, phone);
      return;
    }

    final isOk = body.contains(step.expectedKey);
    if (isOk) {
      _setStep(i, _StepStatus.ok, response: body, note: 'Config correcte ✓');
      await _runStep(i + 1, phone);
    } else {
      _setStep(i, _StepStatus.warning, response: body, note: 'Config incorrecte → correction en cours...');
      _retryCount = 0;
      await _sendAndWait(i, phone, step.fixCmd);
    }
  }

  Future<void> _handleTimeout(int i, String phone) async {
    if (!mounted) return;
    final step = _steps[i];
    _retryCount++;

    if (_retryCount == 1 && _gpsResets < 2) {
      _gpsResets++;
      _setStep(i, _StepStatus.running, note: '⏳ Reset GPS ($_gpsResets/2) — attente 15s...');
      await _sendSms(phone, '&&$_imei,$_pass,Y35');
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;
      await _sendAndWait(i, phone, step.queryCmd);
    } else if (_boitierResets < 1) {
      _boitierResets++;
      _setStep(i, _StepStatus.running, note: '⏳ Reset Boîtier — attente 20s...');
      await _sendSms(phone, '&&$_imei,$_pass,Y36');
      await Future.delayed(const Duration(seconds: 20));
      if (!mounted) return;
      await _sendAndWait(i, phone, step.queryCmd);
    } else if (_gsmResets < 1) {
      _gsmResets++;
      _setStep(i, _StepStatus.running, note: '⏳ Reset GSM + Wake Up — attente 15s...');
      await _sendSms(phone, '&&$_imei,$_pass,Y09');
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      await _sendSms(phone, '&&$_imei,$_pass,Y02');
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;
      await _sendAndWait(i, phone, step.queryCmd);
    } else {
      _setStep(i, _StepStatus.failed, note: '✗ Module ne répond pas après tous les resets');
      _finish(success: false);
    }
  }

  void _finish({bool success = true}) {
    if (!mounted) return;
    setState(() { _running = false; _currentStep = null; _waiting = false; });
    _snack(
      success ? 'Diagnostic terminé ✓' : 'Diagnostic terminé avec erreurs',
      success ? Colors.green : Colors.orange,
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pollTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok   = _steps.where((s) => s.status == _StepStatus.ok).length;
    final warn = _steps.where((s) => s.status == _StepStatus.warning).length;
    final fail = _steps.where((s) => s.status == _StepStatus.failed).length;
    final done = ok + warn + fail;
    final total = _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnostic EasyTrace VII', style: TextStyle(fontSize: 15)),
            Text(widget.moduleName, style: TextStyle(fontSize: 11, color: AppTheme.c2)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info module
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardBlue(radius: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/ET7.jpeg', width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.memory, color: AppTheme.c3, size: 44)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.moduleName, style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('IMEI: ${widget.imei}', style: TextStyle(color: AppTheme.c2, fontSize: 11)),
                      Text('SIM: ${widget.phoneNumber}', style: TextStyle(color: AppTheme.c2, fontSize: 11)),
                    ],
                  )),
                  if (_running)
                    SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.skyBottom)),
                ],
              ),
            ),
            // Barre progression + compteur
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
                        fail > 0 ? Colors.red : warn > 0 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$done/$total étapes', style: TextStyle(color: AppTheme.c2, fontSize: 11)),
                      // Compteur temps d'attente
                      if (_waiting && _currentStep != null && _steps[_currentStep!].sentAt != null)
                        Builder(builder: (_) {
                          final elapsed = DateTime.now().difference(_steps[_currentStep!].sentAt!);
                          final remaining = _timeoutDuration - elapsed;
                          final mins = remaining.inMinutes.clamp(0, 50);
                          final secs = (remaining.inSeconds % 60).clamp(0, 59);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.skyTop.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('⏱ Attente: ${elapsed.inMinutes}m${elapsed.inSeconds % 60}s  |  Timeout: ${mins}m${secs}s',
                                style: TextStyle(color: AppTheme.skyLight, fontSize: 10)),
                          );
                        }),
                      Row(children: [
                        _badge('✓', ok, Colors.green),
                        const SizedBox(width: 4),
                        _badge('⚠', warn, Colors.orange),
                        const SizedBox(width: 4),
                        _badge('✗', fail, Colors.red),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Liste étapes
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _steps.length,
                itemBuilder: (_, i) => _buildStepCard(i),
              ),
            ),
            // Bouton lancer
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_running ? 'Diagnostic en cours...' : 'Lancer le diagnostic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.btnDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      child: Text('$label $count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStepCard(int i) {
    final step = _steps[i];
    final isCurrent = _currentStep == i;

    Color c;
    IconData icon;
    switch (step.status) {
      case _StepStatus.ok:      c = Colors.green;       icon = Icons.check_circle; break;
      case _StepStatus.warning: c = Colors.orange;      icon = Icons.warning_amber_rounded; break;
      case _StepStatus.failed:  c = Colors.red;         icon = Icons.cancel; break;
      case _StepStatus.running: c = AppTheme.skyBottom; icon = Icons.hourglass_top; break;
      default:                  c = Colors.white24;     icon = Icons.radio_button_unchecked;
    }

    // Temps écoulé pour l'étape en cours
    String? elapsedStr;
    if (step.status == _StepStatus.running && step.sentAt != null) {
      final e = DateTime.now().difference(step.sentAt!);
      elapsedStr = '${e.inMinutes}m ${e.inSeconds % 60}s';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(isCurrent ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(isCurrent ? 0.5 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                child: step.status == _StepStatus.running
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c))
                    : Icon(icon, color: c, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.label,
                    style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (elapsedStr != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBottom.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('⏱ $elapsedStr',
                      style: TextStyle(color: AppTheme.skyLight, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Commande envoyée
          Text(step.queryCmd,
              style: TextStyle(color: AppTheme.c2, fontSize: 10, fontFamily: 'monospace')),
          // Note
          if (step.note != null) ...[
            const SizedBox(height: 3),
            Text(step.note!,
                style: TextStyle(color: c, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
          // Réponse SMS COMPLÈTE
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
                    Text('Réponse SMS complète :',
                        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  // Texte sélectionnable et complet
                  SelectableText(
                    step.response!,
                    style: TextStyle(
                      color: c,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.5,
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
}

