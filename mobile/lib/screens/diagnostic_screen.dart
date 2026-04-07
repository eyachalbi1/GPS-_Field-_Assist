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

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _searchController = TextEditingController();
  String _selectedSection = 'update';
  List<_GpsModule> _modules = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<GpsDevice>>? _devicesSubscription;

  // Position section
  final Telephony _telephony = Telephony.instance;
  bool _posWaiting = false;
  String? _posModuleName;
  int? _posLastSmsTime;
  Timer? _posTimer;
  Timer? _posPollingTimer;

  @override
  void initState() {
    super.initState();
    _loadModules();
    _devicesSubscription = GpsDeviceService.devicesStream.listen((devices) {
      if (!mounted) return;
      final apiGpsModules = devices.map((device) {
        return _GpsModule(
          name: device.serialNumber,
          subtitle: 'Type: ${device.equipmentType}',
          serialNumber: device.serialNumber,
          simCardNumber: device.simCardNumber,
          equipmentType: device.equipmentType,
          passwordDevice: device.passwordDevice,
        );
      }).toList();
      setState(() {
        _modules = apiGpsModules;
        _errorMessage = apiGpsModules.isEmpty
            ? 'Aucune donnee disponible depuis l API.'
            : null;
      });
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _searchController.dispose();
    _posTimer?.cancel();
    _posPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadModules() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final devices = await GpsDeviceService.fetchDevices();
      final apiGpsModules = devices.map((device) {
        return _GpsModule(
          name: device.serialNumber,
          subtitle: 'Type: ${device.equipmentType}',
          serialNumber: device.serialNumber,
          simCardNumber: device.simCardNumber,
          equipmentType: device.equipmentType,
          passwordDevice: device.passwordDevice,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _modules = apiGpsModules;
        _errorMessage = apiGpsModules.isEmpty ? 'Aucune donnee disponible depuis l API.' : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'Erreur: $e'; _modules = []; _isLoading = false; });
    }
  }

  void _scanQR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanner QR ouvert'), backgroundColor: Colors.blue),
    );
  }

  // ── Position ──────────────────────────────────────────────────────────────

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

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    _posLastSmsTime = inbox.isNotEmpty ? (inbox.first.date ?? 0) : 0;

    setState(() { _posWaiting = true; _posModuleName = module.name; });

    await _telephony.sendSms(to: normalized, message: '*11*3#');

    _posTimer?.cancel();
    _posTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || !_posWaiting) return;
      setState(() => _posWaiting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pas de réponse GPS (timeout 60s)'),
        backgroundColor: Color(0xFFDC143C),
      ));
    });

    _posPollingTimer?.cancel();
    _posPollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollPosition(),
    );
  }

  Future<void> _pollPosition() async {
    if (!_posWaiting) { _posPollingTimer?.cancel(); return; }
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
            Text('Détails du Module', style: TextStyle(color: AppTheme.c1, fontSize: 18)),
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
            child: Text('Fermer', style: TextStyle(color: AppTheme.c1, fontSize: 16)),
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
            child: Text(label, style: TextStyle(color: AppTheme.c2, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A',
                style: TextStyle(color: AppTheme.c1, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<_GpsModule> get _filteredModules {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _modules;
    return _modules
        .where((m) => m.name.toLowerCase().contains(query) || m.subtitle.toLowerCase().contains(query))
        .toList();
  }

  void _onModuleAction(_GpsModule module) {
    if (_selectedSection == 'position') { _requestPosition(module); return; }
    if (_selectedSection == 'config') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ModuleConfigScreen(moduleName: module.name)));
      return;
    }
    if (_selectedSection == 'diagnostic') {
      final eq = (module.equipmentType ?? '').toLowerCase();
      final isVII = eq.contains('easytrace') && (eq.contains('vii') || eq.contains('7'));
      if (isVII) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EasyTraceVIIDiagScreen(
            moduleName: module.name,
            phoneNumber: module.simCardNumber ?? '',
            imei: module.serialNumber ?? '',
            password: module.passwordDevice ?? '',
          ),
        ));
        return;
      }
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => EasyTraceDiagnosticScreen(moduleName: module.name, phoneNumber: module.simCardNumber ?? ''),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Update lancee pour ${module.name}'), backgroundColor: AppTheme.skyBottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: AppTheme.cardBlue(radius: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.skyTop.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.skyBottom.withOpacity(0.35), width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un module...',
                        hintStyle: TextStyle(color: AppTheme.c2.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.search, color: AppTheme.c2),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanQR,
                  icon: Icon(Icons.qr_code_scanner, color: AppTheme.c1, size: 28),
                  tooltip: 'Scanner QR',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          // ── Section tabs ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildSectionButton('Position', 'position', Icons.location_on)),
                Expanded(child: _buildSectionButton('Mise à jour', 'update', Icons.system_update_alt)),
                Expanded(child: _buildSectionButton('Config', 'config', Icons.settings)),
                Expanded(child: _buildSectionButton('Diagnostic', 'diagnostic', Icons.health_and_safety)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Waiting spinner ──
          if (_posWaiting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3498DB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attente position de $_posModuleName...',
                        style: TextStyle(color: AppTheme.c1, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_errorMessage != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardBlue(radius: 12),
              child: _filteredModules.isEmpty && !_isLoading
                  ? const Center(child: Text('Aucun module trouve', style: TextStyle(color: AppTheme.c2)))
                  : ListView.builder(
                      itemCount: _filteredModules.length,
                      itemBuilder: (context, index) {
                        final module = _filteredModules[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.cardBlue(radius: 14),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 360;
                              final info = Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.darkCard.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: _moduleImage(module.equipmentType ?? '', 36),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: AppTheme.c1, fontSize: 17, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: AppTheme.c2, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final infoButton = IconButton(
                                onPressed: () => _showModuleDetails(module),
                                icon: Icon(Icons.info_outline, color: AppTheme.c2, size: 22),
                                tooltip: 'Voir les details',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  padding: const EdgeInsets.all(8),
                                ),
                              );

                              final actionButton = ElevatedButton(
                                onPressed: () => _onModuleAction(module),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.skyBottom,
                                  foregroundColor: AppTheme.c1,
                                  minimumSize: const Size(104, 40),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(_getActionLabel(), maxLines: 1, overflow: TextOverflow.ellipsis),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    info,
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [infoButton, const SizedBox(width: 8), actionButton],
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
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionButton(String label, String section, IconData icon) {
    final isSelected = _selectedSection == section;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent.withOpacity(0.5) : AppTheme.border(isDark),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : AppTheme.textSubColor(isDark), size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSubColor(isDark),
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
      case 'update': return 'Update';
      case 'config': return 'Configurer';
      case 'diagnostic': return 'Ouvrir';
      case 'position': return 'Visualiser';
      default: return 'Ouvrir';
    }
  }

  Widget _moduleImage(String equipmentType, double size) {
    final n = equipmentType.toLowerCase();
    String? asset;
    if (n.contains('et7') || (n.contains('easytrace') && (n.contains('vii') || n.contains('7')))) asset = 'assets/ET7.jpeg';
    else if (n.contains('etx') || n.contains('easytracex')) asset = 'assets/MT02S-200.jpg';
    else if (n.contains('et8') || n.contains('easytraceviii') || n.contains('easytrace8')) asset = 'assets/MT02S-200.jpg';
    else if (n.contains('et6') || n.contains('easytracevi') || n.contains('easytrace6')) asset = 'assets/MT02S-200.jpg';
    else if (n.contains('easytrace')) asset = 'assets/MT02S-200.jpg';
    else if (n.contains('fm4200')) asset = 'assets/FM4200_v1.92.jpeg';
    else if (n.contains('fm5300')) asset = 'assets/FM5300_ v3.4.jpeg';
    else if (n.contains('fma120')) asset = 'assets/FMA120_v1.17.jpeg';
    else if (n.contains('gt06')) asset = 'assets/GT06N.jpeg';
    else if (n.contains('mt02') || n.contains('multitrace')) asset = 'assets/MT02S-200.jpg';

    if (asset != null) {
      return Image.asset(asset, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.memory, color: AppTheme.c2.withOpacity(0.7), size: size * 0.55));
    }
    return Icon(Icons.memory, color: AppTheme.c2.withOpacity(0.7), size: size * 0.55);
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



