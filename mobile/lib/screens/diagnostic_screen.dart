import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'module_config_screen.dart';
import 'easytrace_diagnostic_screen.dart';
import 'easytrace_vii_diag_screen.dart';
import 'position_map_screen.dart';
import '../services/gps_device_service.dart';
import '../services/gps_prediction_service.dart';
import '../services/sms_history_service.dart';
import '../models/sms_history.dart';
import '../utils/gps_alert_notifier.dart';

// ── Résultat mise à jour EasyCan ──────────────────────────────────────────────
class _UpdateResult {
  final String imei;
  final String phone;
  final String command;
  final String? response;
  final bool waiting;
  final bool success;
  final DateTime sentAt;
  final String? equipmentType;
  const _UpdateResult({
    required this.imei,
    required this.phone,
    required this.command,
    this.response,
    this.waiting = false,
    this.success = false,
    required this.sentAt,
    this.equipmentType,
  });
  _UpdateResult copyWith({String? response, bool? waiting, bool? success}) =>
      _UpdateResult(
        imei: imei,
        phone: phone,
        command: command,
        response: response ?? this.response,
        waiting: waiting ?? this.waiting,
        success: success ?? this.success,
        sentAt: sentAt,
        equipmentType: equipmentType,
      );
}

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => DiagnosticScreenState();
}

class DiagnosticScreenState extends State<DiagnosticScreen> {
  final _searchController = TextEditingController();
  String _selectedSection = 'update';
  List<_GpsModule> _modules = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<GpsDevice>>? _devicesSubscription;
  List<GpsPrediction> _predictions = [];
  bool _alertBlink = false;
  Timer? _blinkTimer;

  // Position section
  final Telephony _telephony = Telephony.instance;
  bool _posWaiting = false;
  String? _posModuleName;
  String? _posCmdSent;
  DateTime? _posSentAt;
  int? _posLastSmsTime;
  Timer? _posTimer;
  Timer? _posPollingTimer;
  Timer? _posUiTimer;
  String? _posEquipmentType;

  // Update EasyCan
  _UpdateResult? _updateResult;
  Timer? _updateTimeoutTimer;
  Timer? _updatePollTimer;
  Timer? _updateUiTimer;
  int? _updateLastSmsTime;

  bool _isEasyCanTrace(String? eq) {
    final n = (eq ?? '').toLowerCase().replaceAll(' ', '');
    return n.contains('easycan') ||
        n.contains('gv300can') ||
        n.contains('canbus');
  }

  @override
  void initState() {
    super.initState();
    _loadModules();
    _devicesSubscription = GpsDeviceService.devicesStream.listen((devices) {
      if (!mounted) return;
      final mods = _devicesToModules(devices);
      final preds = GpsPredictionService.predict(devices);
      setState(() {
        _modules = mods;
        _predictions = preds;
        _errorMessage =
            mods.isEmpty ? 'Aucune donnee disponible depuis l API.' : null;
      });
      _updateBlinkTimer(preds);
    });
  }

  List<_GpsModule> _devicesToModules(List<GpsDevice> devices) => devices
      .map((d) => _GpsModule(
            name: d.serialNumber,
            subtitle: 'Type: ${d.equipmentType}',
            serialNumber: d.serialNumber,
            simCardNumber: d.simCardNumber,
            equipmentType: d.equipmentType,
            passwordDevice: d.passwordDevice,
          ))
      .toList();

  void _updateBlinkTimer(List<GpsPrediction> preds) {
    final count = GpsPredictionService.alertCount(preds);
    gpsAlertNotifier.value = count; // publier pour HomeScreen
    final hasAlert = count > 0;
    if (hasAlert && _blinkTimer == null) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted) setState(() => _alertBlink = !_alertBlink);
      });
    } else if (!hasAlert) {
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _alertBlink = false;
    }
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _searchController.dispose();
    _posTimer?.cancel();
    _posPollingTimer?.cancel();
    _posUiTimer?.cancel();
    _updateTimeoutTimer?.cancel();
    _updatePollTimer?.cancel();
    _updateUiTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final devices = await GpsDeviceService.fetchDevices();
      final mods = _devicesToModules(devices);
      final preds = GpsPredictionService.predict(devices);
      if (!mounted) return;
      setState(() {
        _modules = mods;
        _predictions = preds;
        _errorMessage =
            mods.isEmpty ? 'Aucune donnee disponible depuis l API.' : null;
        _isLoading = false;
      });
      _updateBlinkTimer(preds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur: $e';
        _modules = [];
        _isLoading = false;
      });
    }
  }

  void _scanQR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Scanner QR ouvert'), backgroundColor: Colors.blue),
    );
  }

  // ── Alerte prédiction ──────────────────────────────────────────────────────

  void showAlertPanel() => _showAlertPanel();

  void _showAlertPanel() {
    // Charger dynamiquement les conclusions SMS avant d'afficher
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AlertPanelSheet(
        predictions: _predictions,
        onResolve: (imei) async {
          Navigator.pop(context);
          await GpsDeviceService.updateStatus(imei, 2);
          _loadModules();
        },
        onRelaunch: (imei) async {
          Navigator.pop(context);
          await GpsDeviceService.updateStatus(imei, 3);
          _loadModules();
        },
      ),
    );
  }

  // ── Update EasyCanTrace ────────────────────────────────────────────────────

  Future<void> _launchEasyCanUpdate(_GpsModule module) async {
    final phone =
        (module.simCardNumber ?? '').trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Numero SIM manquant pour ce module'),
        backgroundColor: Color(0xFFDC143C),
      ));
      return;
    }
    // Commande AT+GTUPD — le $ final est construit par concatenation
    final cmd = 'AT+GTUPD=gv300can,0,0,20,0,,,'
            'http://41.226.24.13:5000/api/download/GV300CANR00_0B08_to_0C10.bin'
            ',,0,,,0001' +
        r'$';

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _updateLastSmsTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    setState(() {
      _updateResult = _UpdateResult(
        imei: module.serialNumber ?? '',
        phone: phone,
        command: cmd,
        waiting: true,
        sentAt: DateTime.now(),
        equipmentType: module.equipmentType,
      );
    });

    try {
      await _telephony.sendSms(to: phone, message: cmd);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateResult = _updateResult!
            .copyWith(waiting: false, response: 'Erreur envoi: $e');
      });
      return;
    }

    await SmsHistoryService.addToHistory(SmsHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      phone: phone,
      command: cmd,
      timestamp: DateTime.now(),
      status: SmsHistoryStatus.sent,
      moduleName: module.name,
    ));

    _updateUiTimer?.cancel();
    _updateUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_updateResult?.waiting ?? false)) setState(() {});
    });

    _updateTimeoutTimer?.cancel();
    _updateTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (!mounted || !(_updateResult?.waiting ?? false)) return;
      _updateUiTimer?.cancel();
      _updatePollTimer?.cancel();
      if (mounted)
        setState(() {
          _updateResult = _updateResult!.copyWith(
              waiting: false, response: 'Timeout — pas de reponse apres 3 min');
        });
    });

    _updatePollTimer?.cancel();
    _updatePollTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _pollUpdateResponse());
  }

  Future<void> _pollUpdateResponse() async {
    if (!(_updateResult?.waiting ?? false)) {
      _updatePollTimer?.cancel();
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
      final body = (m.body ?? '').trim();
      if (body.isEmpty || date <= (_updateLastSmsTime ?? 0)) return;
      _updateLastSmsTime = date;
      _updateTimeoutTimer?.cancel();
      _updatePollTimer?.cancel();
      _updateUiTimer?.cancel();
      if (!mounted) return;
      final ok = body.toLowerCase().contains('ok') ||
          body.toLowerCase().contains('upd') ||
          body.toLowerCase().contains('gtupd');
      setState(() {
        _updateResult = _updateResult!
            .copyWith(waiting: false, response: body, success: ok);
      });
      await SmsHistoryService.addToHistory(SmsHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        phone: m.address ?? '',
        command: _updateResult!.command,
        response: body,
        timestamp: DateTime.now(),
        status: SmsHistoryStatus.received,
        moduleName: _updateResult!.imei,
      ));
    } catch (_) {}
  }

  // ── Position ──────────────────────────────────────────────────────────────

  bool _isEasyTraceVII(String? equipmentType) {
    final eq = (equipmentType ?? '').toLowerCase().replaceAll(' ', '');
    return eq.contains('easytracevii') ||
        eq.contains('easytrace7') ||
        eq == 'et7';
  }

  Future<void> _requestPosition(_GpsModule module) async {
    final phone = module.simCardNumber ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Numéro SIM manquant pour ce module'),
        backgroundColor: Color(0xFFDC143C),
      ));
      return;
    }
    final normalized = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');

    // IMEI et password extraits de l'API
    final imei = (module.serialNumber ?? '').trim();
    final pass = (module.passwordDevice ?? '').trim();

    final String posCmd;
    if (_isEasyTraceVII(module.equipmentType) && imei.isNotEmpty) {
      // Commande position EasyTrace VII : &&IMEI,pass,Y01
      posCmd = '&&$imei,${pass.isNotEmpty ? pass : '0000'},Y01';
    } else {
      posCmd = '*11*3#';
    }

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _posLastSmsTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    final isVII = _isEasyTraceVII(module.equipmentType);
    final timeoutDuration =
        isVII ? const Duration(minutes: 5) : const Duration(seconds: 90);

    setState(() {
      _posWaiting = true;
      _posModuleName = module.name;
      _posCmdSent = posCmd;
      _posSentAt = DateTime.now();
      _posEquipmentType = module.equipmentType;
    });

    await _telephony.sendSms(to: normalized, message: posCmd);

    // Rafraîchir le compteur chaque seconde
    _posUiTimer?.cancel();
    _posUiTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_posWaiting && mounted) setState(() {});
      },
    );

    _posTimer?.cancel();
    _posTimer = Timer(timeoutDuration, () {
      if (!mounted || !_posWaiting) return;
      _posUiTimer?.cancel();
      setState(() => _posWaiting = false);
      final mins = timeoutDuration.inMinutes;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Pas de réponse GPS (timeout ${mins > 0 ? '${mins}min' : '90s'})'),
        backgroundColor: const Color(0xFFDC143C),
        duration: const Duration(seconds: 5),
      ));
    });

    _posPollingTimer?.cancel();
    _posPollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollPosition(),
    );
  }

  Future<void> _pollPosition() async {
    if (!_posWaiting) {
      _posPollingTimer?.cancel();
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
      if (body.isEmpty || date <= (_posLastSmsTime ?? 0)) return;
      _posLastSmsTime = date;
      _posTimer?.cancel();
      _posPollingTimer?.cancel();
      _posUiTimer?.cancel();
      if (!mounted) return;
      setState(() => _posWaiting = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PositionMapScreen(
            moduleName: _posModuleName ?? '',
            rawSms: body,
          ),
        ),
      );
    } catch (_) {}
  }

  // ── Module details ─────────────────────────────────────────────────────────

  void _showModuleDetails(_GpsModule module) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.c1, size: 28),
            SizedBox(width: 10),
            Text('Détails du Module',
                style: TextStyle(color: AppTheme.c1, fontSize: 18)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildDetailRow('SerialNumber', module.serialNumber ?? 'N/A'),
              _buildDetailRow('SIMCardNumber', module.simCardNumber ?? 'N/A'),
              _buildDetailRow('EquipmentType', module.equipmentType ?? 'N/A'),
              _buildDetailRow('PasswordDevice', module.passwordDevice ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer',
                style: TextStyle(color: AppTheme.c1, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.c2,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A',
                style: TextStyle(
                    color: AppTheme.c1,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<_GpsModule> get _filteredModules {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _modules;
    return _modules
        .where((m) =>
            m.name.toLowerCase().contains(query) ||
            m.subtitle.toLowerCase().contains(query))
        .toList();
  }

  void _onModuleAction(_GpsModule module) {
    if (_selectedSection == 'position') {
      _requestPosition(module);
      return;
    }
    if (_selectedSection == 'config') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ModuleConfigScreen(moduleName: module.name)));
      return;
    }
    if (_selectedSection == 'diagnostic') {
      final eq = (module.equipmentType ?? '').toLowerCase();
      final isVII =
          eq.contains('easytrace') && (eq.contains('vii') || eq.contains('7'));
      if (isVII) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EasyTraceVIIDiagScreen(
                moduleName: module.name,
                phoneNumber: module.simCardNumber ?? '',
                imei: module.serialNumber ?? '',
                password: module.passwordDevice ?? '',
              ),
            ));
        return;
      }
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EasyTraceDiagnosticScreen(
                moduleName: module.name,
                phoneNumber: module.simCardNumber ?? '',
                equipmentType: module.equipmentType),
          ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Update lancee pour ${module.name}'),
          backgroundColor: AppTheme.skyBottom),
    );
    if (_isEasyCanTrace(module.equipmentType)) {
      _launchEasyCanUpdate(module);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un module...',
                    hintStyle: TextStyle(color: AppTheme.c2.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: AppTheme.c2),
                    filled: true,
                    fillColor: AppTheme.skyTop.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _scanQR,
                icon: Icon(Icons.qr_code_scanner, color: AppTheme.c1, size: 26),
                tooltip: 'Scanner QR',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Section tabs ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                  child: _buildSectionButton(
                      'Position', 'position', Icons.location_on)),
              Expanded(
                  child: _buildSectionButton(
                      'Mise à jour', 'update', Icons.system_update_alt)),
              Expanded(
                  child:
                      _buildSectionButton('Config', 'config', Icons.settings)),
              Expanded(
                  child: _buildSectionButton(
                      'Diagnostic', 'diagnostic', Icons.health_and_safety)),
              Expanded(
                  child: _buildSectionButton(
                      'STAT', 'stat', Icons.bar_chart_rounded)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Waiting spinner ──
        if (_posWaiting)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.skyBottom.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.skyBottom.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _moduleImage(_posEquipmentType ?? '', 32),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.skyBottom),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Attente position — $_posModuleName',
                          style: const TextStyle(
                              color: AppTheme.c1,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_posSentAt != null)
                        Text(
                          () {
                            final e = DateTime.now().difference(_posSentAt!);
                            return '${e.inMinutes}m ${e.inSeconds % 60}s';
                          }(),
                          style: const TextStyle(
                              color: AppTheme.skyLight, fontSize: 11),
                        ),
                    ],
                  ),
                  if (_posCmdSent != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _posCmdSent!,
                      style: const TextStyle(
                          color: AppTheme.c2,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        // ── Carte résultat mise à jour EasyCan ──
        if (_updateResult != null && _selectedSection == 'update')
          _buildUpdateResultCard(),
        if (_errorMessage != null && !_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        Expanded(
          child: _selectedSection == 'stat'
              ? _buildStatSection()
              : _filteredModules.isEmpty && !_isLoading
                  ? const Center(
                      child: Text('Aucun module trouve',
                          style: TextStyle(color: AppTheme.c2)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                      itemCount: _filteredModules.length,
                      itemBuilder: (context, index) {
                        final module = _filteredModules[index];
                        // Trouver la prédiction correspondante
                        final pred = _predictions.firstWhere(
                          (p) => p.imei == module.serialNumber,
                          orElse: () => GpsPrediction(
                            imei: module.serialNumber ?? '',
                            equipmentType: module.equipmentType ?? '',
                            rawStatus: 2,
                            status: GpsPredictedStatus.ok,
                            label: 'OK',
                            description: '',
                            recommendation: '',
                          ),
                        );
                        return GestureDetector(
                          onLongPress:
                              pred.needsAlert ? () => _showAlertPanel() : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBlue(radius: 0).color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: pred.color.withOpacity(0.75),
                                width: 1.8,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;
                                final info = Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkCard
                                                .withOpacity(0.7),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: _moduleImage(
                                                module.equipmentType ?? '', 36),
                                          ),
                                        ),
                                        // Point coloré statut
                                        Positioned(
                                          bottom: -2,
                                          right: -2,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: pred.color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: AppTheme.darkCard,
                                                  width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(module.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: AppTheme.c1,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Row(children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                  color: pred.color,
                                                  shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(pred.label,
                                                style: TextStyle(
                                                    color: pred.color,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(module.subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: AppTheme.c2,
                                                      fontSize: 11)),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                  ],
                                );

                                final infoButton = IconButton(
                                  onPressed: () => _showModuleDetails(module),
                                  icon: Icon(Icons.info_outline,
                                      color: AppTheme.c2, size: 22),
                                  tooltip: 'Voir les details',
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.15),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                );

                                final actionButton = ElevatedButton(
                                  onPressed: () => _onModuleAction(module),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.skyBottom,
                                    foregroundColor: AppTheme.c1,
                                    minimumSize: const Size(104, 40),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text(_getActionLabel(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                );

                                if (compact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      info,
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          infoButton,
                                          const SizedBox(width: 8),
                                          actionButton
                                        ],
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: info),
                                    const SizedBox(width: 8),
                                    infoButton,
                                    const SizedBox(width: 10),
                                    actionButton,
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Carte résultat mise à jour EasyCan ─────────────────────────────────────────────
  Widget _buildUpdateResultCard() {
    final r = _updateResult!;
    final elapsed = DateTime.now().difference(r.sentAt);
    final elapsedStr = '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';

    final Color cardColor;
    final IconData cardIcon;
    final String statusLabel;
    if (r.waiting) {
      cardColor = const Color(0xFF5DA5B3);
      cardIcon = Icons.system_update_alt;
      statusLabel = 'Attente réponse… $elapsedStr';
    } else if (r.success) {
      cardColor = const Color(0xFF26C6A6);
      cardIcon = Icons.check_circle_rounded;
      statusLabel = 'Mise à jour confirmée';
    } else {
      cardColor = r.response != null && r.response!.startsWith('Timeout')
          ? const Color(0xFFFFB347)
          : const Color(0xFFFF4444);
      cardIcon = r.response != null && r.response!.startsWith('Timeout')
          ? Icons.timer_off_outlined
          : Icons.error_outline;
      statusLabel = r.response != null && r.response!.startsWith('Timeout')
          ? 'Timeout'
          : 'Echec';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardColor.withOpacity(0.5), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _moduleImage(r.equipmentType ?? '', 32),
            ),
            const SizedBox(width: 8),
            r.waiting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cardColor)))
                : Icon(cardIcon, color: cardColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('EasyCanTrace — Mise à jour FW',
                  style: TextStyle(
                      color: cardColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardColor.withOpacity(0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: cardColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _updateResult = null),
              child: Icon(Icons.close,
                  size: 16, color: AppTheme.c2.withOpacity(0.5)),
            ),
          ]),
          const SizedBox(height: 10),
          // IMEI + phone
          Row(children: [
            Icon(Icons.memory, size: 11, color: AppTheme.c2.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(r.imei,
                style: TextStyle(
                    color: AppTheme.c2.withOpacity(0.7), fontSize: 10)),
            const SizedBox(width: 10),
            Icon(Icons.sim_card, size: 11, color: AppTheme.c2.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(r.phone,
                style: TextStyle(
                    color: AppTheme.c2.withOpacity(0.7), fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          // Commande envoyée
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(r.command,
                style: const TextStyle(
                    color: AppTheme.c2, fontSize: 10, fontFamily: 'monospace'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          // Réponse GPS
          if (r.response != null && !r.waiting) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardColor.withOpacity(0.3)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.reply, size: 13, color: cardColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.response!,
                      style: TextStyle(
                          color: cardColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                ),
              ]),
            ),
          ],
          // Bouton réessayer si échec
          if (!r.waiting && !r.success) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final mod = _modules.firstWhere(
                    (m) => m.serialNumber == r.imei,
                    orElse: () => _GpsModule(
                        name: r.imei, subtitle: '', simCardNumber: r.phone),
                  );
                  _launchEasyCanUpdate(mod);
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: cardColor),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Normalise equipmentType → nom court lisible ──────────────────────────
  String _normalizeModel(String raw) {
    final n = raw.toLowerCase().replaceAll(' ', '');
    if (n.contains('et7') ||
        (n.contains('easytrace') && (n.contains('vii') || n.contains('7'))))
      return 'EasyTrace VII';
    if (n.contains('etx') || n.contains('easytracex')) return 'EasyTrace X';
    if (n.contains('et8') ||
        n.contains('easytraceviii') ||
        n.contains('easytrace8')) return 'EasyTrace VIII';
    if (n.contains('et6') ||
        n.contains('easytracevi') ||
        n.contains('easytrace6')) return 'EasyTrace VI';
    if (n.contains('easytrace')) return 'EasyTrace';
    if (n.contains('fm4200')) return 'FM4200';
    if (n.contains('fm5300')) return 'FM5300';
    if (n.contains('fma120')) return 'FMA120';
    if (n.contains('gt06')) return 'GT06N';
    if (n.contains('mt02') || n.contains('multitrace')) return 'MT02S';
    return raw.isNotEmpty ? raw : 'Inconnu';
  }

  // ── STAT section ───────────────────────────────────────────────────────────
  Widget _buildStatSection() {
    final total = _predictions.length;
    final ok =
        _predictions.where((p) => p.status == GpsPredictedStatus.ok).length;
    final alerts = _predictions.where((p) => p.needsAlert).length;
    final byStatus = <GpsPredictedStatus, List<GpsPrediction>>{};
    for (final p in _predictions) {
      byStatus.putIfAbsent(p.status, () => []).add(p);
    }

    // Taux de santé global
    final healthPct = total == 0 ? 0.0 : ok / total;

    // Couleur globale
    final healthColor = healthPct >= 0.8
        ? const Color(0xFF26C6A6)
        : healthPct >= 0.5
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF4444);

    // ── Stats par modèle GPS ──
    // Regrouper les prédictions par modèle normalisé
    final byModel = <String, List<GpsPrediction>>{};
    for (final p in _predictions) {
      final model = _normalizeModel(p.equipmentType);
      byModel.putIfAbsent(model, () => []).add(p);
    }
    // Trier par nombre d'interventions décroissant
    final sortedModels = byModel.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        // ── Titre ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            const Icon(Icons.analytics_outlined,
                color: AppTheme.skyBottom, size: 20),
            const SizedBox(width: 8),
            const Text('Maintenance Prédictive',
                style: TextStyle(
                    color: AppTheme.c1,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: _loadModules,
              child: const Icon(Icons.refresh, color: AppTheme.c2, size: 18),
            ),
          ]),
        ),

        // ── Score santé global ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: healthColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: healthColor.withOpacity(0.4)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.monitor_heart_outlined, color: healthColor, size: 18),
              const SizedBox(width: 8),
              Text('Santé globale du parc',
                  style: TextStyle(
                      color: healthColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(healthPct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: healthColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: healthPct,
                minHeight: 10,
                backgroundColor: AppTheme.skyTop.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(healthColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _statChip(Icons.check_circle_outline, '$ok', 'OK',
                  const Color(0xFF26C6A6)),
              const SizedBox(width: 8),
              _statChip(Icons.warning_amber_rounded, '$alerts', 'Alertes',
                  const Color(0xFFFF4444)),
              const SizedBox(width: 8),
              _statChip(Icons.devices, '$total', 'Total', AppTheme.skyLight),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Répartition par statut ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.skyTop.withOpacity(0.3)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Répartition par statut',
                style: TextStyle(
                    color: AppTheme.c1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...GpsPredictedStatus.values.map((s) {
              final count = byStatus[s]?.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final pct = total == 0 ? 0.0 : count / total;
              final color = byStatus[s]!.first.color;
              final label = byStatus[s]!.first.label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(byStatus[s]!.first.icon, color: color, size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500))),
                        Text('$count module${count > 1 ? 's' : ''}',
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppTheme.skyTop.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Modules nécessitant une intervention ──
        if (alerts > 0) ...[
          GestureDetector(
            onTap: _showAlertPanel,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFF4444).withOpacity(0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.build_circle_outlined,
                    color: Color(0xFFFF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  '$alerts module(s) nécessitent une intervention — Appuyer pour analyser',
                  style: const TextStyle(
                      color: Color(0xFFFF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                )),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFFF4444), size: 18),
              ]),
            ),
          ),
        ],

        // ── Message si tout est OK ──
        if (alerts == 0 && total > 0)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6A6).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF26C6A6).withOpacity(0.35)),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF26C6A6), size: 20),
                  SizedBox(width: 10),
                  Text('Tous les modules sont opérationnels',
                      style: TextStyle(
                          color: Color(0xFF26C6A6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
          ),

        if (total == 0)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('Aucune donnée disponible',
                  style: TextStyle(color: AppTheme.c2)),
            ),
          ),

        // ── Section : Statistiques par modèle GPS ──
        if (sortedModels.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildModelStatsSection(sortedModels),
        ],
      ],
    );
  }

  // ── Widget principal : stats par modèle ────────────────────────────────────
  Widget _buildModelStatsSection(
      List<MapEntry<String, List<GpsPrediction>>> sortedModels) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.skyTop.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Titre section
        Row(children: [
          const Icon(Icons.memory, color: Color(0xFF26C6A6), size: 16),
          const SizedBox(width: 8),
          const Text('Statistiques par modèle GPS',
              style: TextStyle(
                  color: AppTheme.c1,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text('${sortedModels.length} modèle(s) détecté(s)',
            style:
                TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 10)),
        const SizedBox(height: 14),

        // Légende colonnes
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const SizedBox(width: 28), // image
            Expanded(
                flex: 3,
                child: Text('Modèle',
                    style: TextStyle(
                        color: AppTheme.c2.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600))),
            Expanded(
                child: Text('Appareils',
                    style: TextStyle(
                        color: AppTheme.c2.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center)),
            Expanded(
                child: Text('Santé',
                    style: TextStyle(
                        color: AppTheme.c2.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center)),
            Expanded(
                child: Text('SMS OK',
                    style: TextStyle(
                        color: AppTheme.c2.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center)),
          ]),
        ),

        // Ligne par modèle
        ...sortedModels.map((e) => _buildModelRow(e.key, e.value)),

        const SizedBox(height: 10),
        // Légende SMS
        FutureBuilder<List<SmsHistoryItem>>(
          future: SmsHistoryService.getHistory(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.isEmpty)
              return const SizedBox.shrink();
            return Row(children: [
              const Icon(Icons.info_outline, size: 10, color: AppTheme.c2),
              const SizedBox(width: 4),
              Text(
                  'Taux SMS basé sur ${snap.data!.length} commande(s) envoyée(s)',
                  style: TextStyle(
                      color: AppTheme.c2.withOpacity(0.5),
                      fontSize: 9,
                      fontStyle: FontStyle.italic)),
            ]);
          },
        ),
      ]),
    );
  }

  // ── Ligne d'un modèle ──────────────────────────────────────────────────────
  Widget _buildModelRow(String model, List<GpsPrediction> preds) {
    final total = preds.length;
    final okCount =
        preds.where((p) => p.status == GpsPredictedStatus.ok).length;
    final healthPct = total == 0 ? 0.0 : okCount / total;
    final healthColor = healthPct >= 0.8
        ? const Color(0xFF26C6A6)
        : healthPct >= 0.5
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF4444);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 22,
            height: 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _moduleImage(model, 22),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(model,
                style: const TextStyle(
                    color: AppTheme.c1,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          // Colonne : nombre d'appareils
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.skyLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$total',
                    style: const TextStyle(
                        color: AppTheme.skyLight,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            ),
          ),
          // Colonne : taux de santé
          Expanded(
            child: Center(
              child: Text('${(healthPct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: healthColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
          ),
          // Colonne : taux SMS (FutureBuilder)
          Expanded(
            child: FutureBuilder<List<SmsHistoryItem>>(
              future: SmsHistoryService.getHistory(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppTheme.c2)));
                }
                final allSms = snap.data!;
                // Filtrer les SMS liés à ce modèle via moduleName
                final modelSms = allSms.where((s) {
                  final mn = (s.moduleName ?? '').toLowerCase();
                  return _normalizeModel(mn) == model ||
                      mn.contains(model.toLowerCase().replaceAll(' ', ''));
                }).toList();
                if (modelSms.isEmpty) {
                  return Center(
                      child: Text('—',
                          style: TextStyle(
                              color: AppTheme.c2.withOpacity(0.4),
                              fontSize: 12),
                          textAlign: TextAlign.center));
                }
                final successCount = modelSms
                    .where((s) =>
                        s.status == SmsHistoryStatus.sent ||
                        s.status == SmsHistoryStatus.delivered ||
                        s.status == SmsHistoryStatus.received)
                    .length;
                final smsPct = successCount / modelSms.length;
                final smsColor = smsPct >= 0.8
                    ? const Color(0xFF26C6A6)
                    : smsPct >= 0.5
                        ? const Color(0xFFFFB347)
                        : const Color(0xFFFF4444);
                return Center(
                  child: Text('${(smsPct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: smsColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                );
              },
            ),
          ),
        ]),
        const SizedBox(height: 5),
        // Barre de santé
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: healthPct,
            minHeight: 4,
            backgroundColor: AppTheme.skyTop.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(healthColor),
          ),
        ),
      ]),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ]),
      );

  Widget _buildSectionButton(String label, String section, IconData icon) {
    final isSelected = _selectedSection == section;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withOpacity(0.5)
                : AppTheme.border(isDark),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.textSubColor(isDark),
                size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.textSubColor(isDark),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel() {
    switch (_selectedSection) {
      case 'update':
        return 'Update';
      case 'config':
        return 'Configurer';
      case 'diagnostic':
        return 'Ouvrir';
      case 'position':
        return 'Visualiser';
      default:
        return 'Ouvrir';
    }
  }

  Widget _moduleImage(String equipmentType, double size) {
    final n = equipmentType.toLowerCase();
    String? asset;
    if (n.contains('et7') ||
        (n.contains('easytrace') && (n.contains('vii') || n.contains('7'))))
      asset = 'assets/ET7.jpeg';
    else if (n.contains('etx') || n.contains('easytracex'))
      asset = 'assets/MT02S-200.jpg';
    else if (n.contains('et8') ||
        n.contains('easytraceviii') ||
        n.contains('easytrace8'))
      asset = 'assets/MT02S-200.jpg';
    else if (n.contains('et6') ||
        n.contains('easytracevi') ||
        n.contains('easytrace6'))
      asset = 'assets/MT02S-200.jpg';
    else if (n.contains('easytrace'))
      asset = 'assets/MT02S-200.jpg';
    else if (n.contains('fm4200'))
      asset = 'assets/FM4200_v1.92.jpeg';
    else if (n.contains('fm5300'))
      asset = 'assets/FM5300_ v3.4.jpeg';
    else if (n.contains('fma120'))
      asset = 'assets/FMA120_v1.17.jpeg';
    else if (n.contains('gt06'))
      asset = 'assets/GT06N.jpeg';
    else if (n.contains('gv300') ||
        n.contains('gv300can') ||
        n.contains('easycantrace') ||
        n.contains('easycan'))
      asset = 'assets/gv300can-gps.jpg.jpeg';
    else if (n.contains('mt02') || n.contains('multitrace'))
      asset = 'assets/MT02S-200.jpg';

    if (asset != null) {
      return Image.asset(asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.memory,
              color: AppTheme.c2.withOpacity(0.7), size: size * 0.55));
    }
    return Icon(Icons.memory,
        color: AppTheme.c2.withOpacity(0.7), size: size * 0.55);
  }
}

// ── Panel d'alerte dynamique (chargé au tap sur l'alarme) ──────────────────
class _AlertPanelSheet extends StatefulWidget {
  final List<GpsPrediction> predictions;
  final Future<void> Function(String imei) onResolve;
  final Future<void> Function(String imei) onRelaunch;

  const _AlertPanelSheet({
    required this.predictions,
    required this.onResolve,
    required this.onRelaunch,
  });

  @override
  State<_AlertPanelSheet> createState() => _AlertPanelSheetState();
}

class _AlertPanelSheetState extends State<_AlertPanelSheet> {
  bool _loading = true;
  List<GpsPrediction> _enriched = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devices = GpsDeviceService.getCachedDevices();
    final enriched = await GpsPredictionService.predictWithSms(devices);
    if (!mounted) return;
    setState(() {
      _enriched = enriched.where((p) => p.needsAlert).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppTheme.c2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF4444), size: 20),
              const SizedBox(width: 8),
              Text(
                _loading
                    ? 'Analyse en cours...'
                    : '${_enriched.length} module(s) en alerte',
                style: const TextStyle(
                    color: AppTheme.c1,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              if (_loading) ...[
                const SizedBox(width: 10),
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFF4444))),
              ],
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4444)))
                : ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: _enriched.map((p) => _buildCard(p)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(GpsPrediction p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: p.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withOpacity(0.55), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4, color: p.color),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(p.icon, color: p.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(p.imei,
                              style: TextStyle(
                                  color: p.color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.color.withOpacity(0.4)),
                        ),
                        child: Text(p.label,
                            style: TextStyle(
                                color: p.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(p.equipmentType,
                        style: TextStyle(
                            color: AppTheme.c2.withOpacity(0.7), fontSize: 11)),
                    const SizedBox(height: 8),
                    // Description dynamique basée sur les SMS réels
                    Text(
                      p.dynamicDescription.isNotEmpty
                          ? p.dynamicDescription
                          : p.description,
                      style: const TextStyle(
                          color: AppTheme.c2, fontSize: 12, height: 1.4),
                    ),
                    // Conclusions dynamiques
                    if (p.dynamicConclusion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.color.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.color.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.analytics_outlined,
                                  size: 12, color: p.color),
                              const SizedBox(width: 5),
                              Text('Conclusions SMS',
                                  style: TextStyle(
                                      color: p.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 6),
                            Text(p.dynamicConclusion,
                                style: TextStyle(
                                    color: p.color, fontSize: 11, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                    // Dernières réponses SMS brutes
                    if (p.smsResponses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Dernière réponse SMS :',
                          style: TextStyle(
                              color: AppTheme.c2.withOpacity(0.6),
                              fontSize: 10)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          p.smsResponses.first,
                          style: const TextStyle(
                              color: AppTheme.c2,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (p.rawStatus == 3)
                        TextButton.icon(
                          onPressed: () => widget.onResolve(p.imei),
                          icon:
                              const Icon(Icons.check_circle_outline, size: 14),
                          label: const Text('Marquer résolu',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF26C6A6)),
                        ),
                      if (p.rawStatus == 4)
                        TextButton.icon(
                          onPressed: () => widget.onRelaunch(p.imei),
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Relancer diagnostic',
                              style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFB347)),
                        ),
                    ]),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsModule {
  final String name;
  final String subtitle;
  final String? serialNumber;
  final String? simCardNumber;
  final String? equipmentType;
  final String? passwordDevice;

  const _GpsModule({
    required this.name,
    required this.subtitle,
    this.serialNumber,
    this.simCardNumber,
    this.equipmentType,
    this.passwordDevice,
  });
}
//TODO: add passwordDevice      //TODO: add equipmentType    //TODO: add serialNumber
