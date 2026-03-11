import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gps_device_service.dart';
import 'pdf_viewer_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _imeiController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final Telephony _telephony = Telephony.instance;

  bool _isSending = false;
  List<Map<String, String?>> _modules = [];
  String? _selectedModule;
  bool _isLoadingModules = true;
  Timer? _modulesRefreshTimer;
  StreamSubscription<List<GpsDevice>>? _devicesSubscription;

  @override
  void initState() {
    super.initState();
    _loadModules();
    _startModulesAutoRefresh();
    _devicesSubscription = GpsDeviceService.devicesStream.listen((devices) {
      if (!mounted) return;
      setState(() {
        _modules = devices.map((d) => d.toMap()).toList();
      });
    });
  }

  void _startModulesAutoRefresh() {
    _modulesRefreshTimer?.cancel();
    _modulesRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadModules(silent: true),
    );
  }

  Future<void> _loadModules({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingModules = true);
    }
    try {
      final devices = await GpsDeviceService.fetchDevices();
      final loadedModules = devices.map((d) => d.toMap()).toList();
      if (!mounted) return;

      final currentSelection = _selectedModule;
      _modules = loadedModules;

      if (currentSelection != null) {
        final exists = _modules.any(
          (m) => m['SerialNumber'] == currentSelection,
        );
        if (!exists) {
          _selectedModule = null;
        }
      }
    } catch (e) {
      _modules = [];
    } finally {
      if (mounted) {
        setState(() => _isLoadingModules = false);
      }
    }
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  void dispose() {
    _imeiController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _modulesRefreshTimer?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }

  String _buildSmsMessage() {
    // Simple test message
    return 'TEST GPS';
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

  Future<void> _sendSMS() async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numero de telephone')),
      );
      return;
    }

    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Envoi SMS direct supporte uniquement sur Android.'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ce telephone ne supporte pas l envoi SMS.'),
          ),
        );
        return;
      }

      final hasPermission = await _telephony.requestSmsPermissions;
      if (hasPermission != true) {
        final message = _buildSmsMessage();
        final opened = await _openSmsAppFallback(
          phone: phone,
          message: message,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Permission SMS refusee. Ouverture de l app Messages.'
                  : 'Permission SMS refusee. Autorisez-la dans les parametres.',
            ),
          ),
        );
        return;
      }

      final message = _buildSmsMessage();
      try {
        await _telephony.sendSms(
          to: phone,
          message: message,
          isMultipart: message.length > 160,
          statusListener: (status) {
            if (!mounted) return;
            final text =
                status == SendStatus.DELIVERED ? 'SMS livre' : 'SMS envoye';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$text vers $phone'),
                backgroundColor: status == SendStatus.DELIVERED
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFF3498DB),
              ),
            );
          },
        );
      } catch (_) {
        await _telephony.sendSmsByDefaultApp(to: phone, message: message);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ouverture de l app SMS par defaut pour $phone'),
            backgroundColor: const Color(0xFF3498DB),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande SMS lancee vers $phone'),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      // Silent fail - don't display error to user
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _openPDF() async {
    const pdfFile = 'assets/pdfs_modules/GPSTrackerManual-2016.pdf';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PdfViewerScreen(pdfPath: pdfFile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        backgroundColor: const Color(0xFF0066FF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fond tunav.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Configuration generale',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _modules.isNotEmpty
                            ? '${_modules.length} modules charges depuis l API'
                            : 'Aucun module charge depuis l API',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _loadModules(),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Recharger depuis l API',
                    ),
                  ],
                ),
                if (_isLoadingModules)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Chargement des modules...'),
                      ],
                    ),
                  )
                else if (_modules.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedModule,
                      decoration: InputDecoration(
                        labelText: 'Sélectionner un module GPS',
                        labelStyle: const TextStyle(color: Color(0xFF0066FF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.gps_fixed,
                          color: Color(0xFF0066FF),
                        ),
                      ),
                      items: _modules.map((module) {
                        final serial = module['SerialNumber'] ?? '';
                        final type = module['EquipmentType'] ?? '';
                        return DropdownMenuItem(
                          value: serial,
                          child: Text('$type - $serial'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedModule = value;
                          final module = _modules.firstWhere(
                            (m) => m['SerialNumber'] == value,
                          );
                          _phoneController.text = module['SIMCardNumber'] ?? '';
                          _descriptionController.text =
                              module['EquipmentType'] ?? '';
                        });
                      },
                    ),
                  ),
                if (!_isLoadingModules && _modules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Aucune donnee disponible depuis l API. Verifiez la connexion serveur puis rechargez.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _imeiController,
                    decoration: InputDecoration(
                      labelText: 'Numero IMEI du telephone',
                      labelStyle: const TextStyle(color: Color(0xFF0066FF)),
                      hintText: 'Ex: 352099087484613',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_android,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description du module',
                      labelStyle: const TextStyle(color: Color(0xFF0066FF)),
                      hintText: 'Entrez une description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.description,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Communication par SMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Entrez un numero de telephone puis appuyez sur Envoyer SMS. Le SMS sera envoye directement depuis cette application.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Numero de telephone',
                      labelStyle: const TextStyle(color: Color(0xFF0066FF)),
                      hintText: 'Ex: +21622000000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendSMS,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sms, size: 24),
                  label: Text(_isSending ? 'Envoi en cours...' : 'Envoyer SMS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF48C9B0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF7EDCCB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openPDF,
                  icon: const Icon(Icons.picture_as_pdf, size: 24),
                  label: const Text('Consulter le Manuel (PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
