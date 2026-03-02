import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

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
    super.dispose();
  }

  String _buildSmsMessage() {
    final imei = _imeiController.text.trim();
    final description = _descriptionController.text.trim();

    final buffer = StringBuffer('TEST GPS FIELD ASSIST');
    if (imei.isNotEmpty) {
      buffer.write('\nIMEI: $imei');
    }
    if (description.isNotEmpty) {
      buffer.write('\nDescription: $description');
    }
    buffer.write('\nStatut: Test SMS depuis application');
    return buffer.toString();
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
        final opened = await _openSmsAppFallback(phone: phone, message: message);
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
                    ? Colors.green
                    : Colors.blue,
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
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande SMS lancee vers $phone'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Echec envoi SMS: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
