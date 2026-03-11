import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';

class SequentialSmsScreen extends StatefulWidget {
  final String phoneNumber;
  final String moduleName;

  const SequentialSmsScreen({
    super.key,
    required this.phoneNumber,
    required this.moduleName,
  });

  @override
  State<SequentialSmsScreen> createState() => _SequentialSmsScreenState();
}

class _SequentialSmsScreenState extends State<SequentialSmsScreen> {
  final Telephony _telephony = Telephony.instance;
  final List<Map<String, dynamic>> _commands = [];
  int _currentCommandIndex = 0;
  bool _isSending = false;
  bool _isListening = false;
  Timer? _pollingTimer;
  int? _lastSmsCheckTime;
  int _totalMessagesSent = 0;
  String? _lastMessageSent;
  DateTime? _lastMessageTime;
  String? _lastResponse;

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  void initState() {
    super.initState();
    _initializeCommands();
    _requestPermissionsAndStartListening();
  }

  void _initializeCommands() {
    final commandsList = [
      'APN,internet.tn#',
      'APN,apn.tunav.tn#',
      'APN,m2m.tunav.com,tunav,tunav#',
      'PROTOCOL,3,1#',
      'IP,41.226.27.169,85,1#',
      'HC,60,7200,7200#',
      'CORNER,20#',
      'UTC,0#',
      'SLEEP,0#',
      'LINE,4,1#',
      '*11*4#',
      '*11*3#',
      'STATUS#',
      'CLR,BLIND#',
      'RESET#',
    ];

    _commands.addAll(commandsList.map((cmd) => {
          'command': cmd,
          'status': 'pending',
          'response': null,
          'sendTime': null,
        }));
  }

  Future<void> _requestPermissionsAndStartListening() async {
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
                  Text('Ecoute SMS activee'),
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
                  Expanded(child: Text('Permission SMS refusee')),
                ],
              ),
              backgroundColor: Color(0xFFFFA500),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail - don't display error to user
    }
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

    final normalizedSender = _normalizePhone(sender);
    final normalizedExpected = _normalizePhone(widget.phoneNumber);

    if (normalizedSender != normalizedExpected) {
      debugPrint(
          'SMS ignoré - expéditeur différent: $normalizedSender vs $normalizedExpected');
      return;
    }

    // Trouver la première commande en attente de réponse
    int waitingIndex = -1;
    for (int i = 0; i < _commands.length; i++) {
      if (_commands[i]['status'] == 'waiting') {
        waitingIndex = i;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _lastResponse = body;

        if (waitingIndex >= 0) {
          _commands[waitingIndex]['response'] = body;
          _commands[waitingIndex]['status'] = 'sent';
        }

        _isSending = false;
      });

      // Afficher la réponse dans un message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Reponse GPS recue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  body,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2ECC71),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _checkForNewSms() async {
    int waitingIndex = -1;
    for (int i = 0; i < _commands.length; i++) {
      if (_commands[i]['status'] == 'waiting') {
        waitingIndex = i;
        break;
      }
    }

    if (waitingIndex < 0) return;

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals(_normalizePhone(widget.phoneNumber)),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty) {
        final lastMsg = messages.first;
        final msgDate = lastMsg.date;

        if (msgDate != null &&
            (_lastSmsCheckTime == null || msgDate > _lastSmsCheckTime!)) {
          _lastSmsCheckTime = msgDate;
          _handleIncomingSms(lastMsg);
        }
      }
    } catch (e) {
      // Silent fail - don't display error to user
    }
  }

  Future<void> _sendNextCommand() async {
    // Trouver la première commande en attente
    int pendingIndex = -1;
    for (int i = 0; i < _commands.length; i++) {
      if (_commands[i]['status'] == 'pending') {
        pendingIndex = i;
        break;
      }
    }

    if (pendingIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les commandes ont ete envoyees'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
      return;
    }

    // Vérifier si la commande précédente est encore en attente
    if (pendingIndex > 0 &&
        _commands[pendingIndex - 1]['status'] == 'waiting') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Attendez la reponse de la commande precedente'),
            ],
          ),
          backgroundColor: Color(0xFFFFA500),
        ),
      );
      return;
    }

    setState(() {
      _commands[pendingIndex]['status'] = 'sending';
      _commands[pendingIndex]['sendTime'] = DateTime.now();
      _isSending = true;
    });

    final command = _commands[pendingIndex]['command'];
    _lastSmsCheckTime = DateTime.now().millisecondsSinceEpoch;
    _lastMessageSent = command;
    _lastMessageTime = DateTime.now();
    _totalMessagesSent++;

    try {
      final result = await _telephony.sendSms(
        to: widget.phoneNumber,
        message: command,
      );

      if (!mounted) return;

      // SMS envoyé avec succès
      setState(() {
        _commands[pendingIndex]['status'] = 'waiting';
        _commands[pendingIndex]['response'] = 'En attente de reponse...';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Commande envoyee: $command')),
            ],
          ),
          backgroundColor: const Color(0xFF2ECC71),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _commands[pendingIndex]['status'] = 'failed';
        _commands[pendingIndex]['response'] = 'Erreur: ${e.toString()}';
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Erreur: ${e.toString()}')),
            ],
          ),
          backgroundColor: const Color(0xFFDC143C),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendAllCommands() async {
    // Envoyer toutes les commandes en attente
    for (int i = 0; i < _commands.length; i++) {
      if (_commands[i]['status'] == 'pending') {
        await _sendNextCommand();
        // Attendre un peu entre chaque envoi
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _showInfoDialog() {
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
              'Informations',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Nombre total de messages', '$_totalMessagesSent'),
              _buildInfoRow(
                  'Ecoute SMS', _isListening ? 'Activee' : 'Desactivee'),
              _buildInfoRow('Dernier message', _lastMessageSent ?? 'Aucun'),
              _buildInfoRow(
                  'Heure du dernier envoi',
                  _lastMessageTime != null
                      ? '${_lastMessageTime!.hour.toString().padLeft(2, '0')}:${_lastMessageTime!.minute.toString().padLeft(2, '0')}:${_lastMessageTime!.second.toString().padLeft(2, '0')}'
                      : 'N/A'),
              _buildInfoRow(
                  'Date',
                  _lastMessageTime != null
                      ? '${_lastMessageTime!.day}/${_lastMessageTime!.month}/${_lastMessageTime!.year}'
                      : 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0C4D7A),
                child: Row(
                  children: [
                    const Text(
                      'Historique SMS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _commands.where((c) => c['status'] != 'pending').length,
                  itemBuilder: (context, index) {
                    final sentCommands = _commands
                        .where((c) => c['status'] != 'pending')
                        .toList();
                    final cmd = sentCommands[index];
                    final status = cmd['status'];
                    final sendTime = cmd['sendTime'] as DateTime?;
                    final response = cmd['response'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Color(0xFF0C4D7A)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.phoneNumber,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  status == 'sent'
                                      ? Icons.check_circle
                                      : Icons.hourglass_empty,
                                  color: status == 'sent'
                                      ? const Color(0xFF2ECC71)
                                      : const Color(0xFFFFA500),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cmd['command'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: status == 'sent'
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'sent'
                                    ? const Color(0xFF2ECC71).withOpacity(0.2)
                                    : status == 'waiting'
                                        ? const Color(0xFFFFA500)
                                            .withOpacity(0.2)
                                        : const Color(0xFFDC143C)
                                            .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status == 'sent'
                                    ? 'Envoye'
                                    : status == 'waiting'
                                        ? 'En attente'
                                        : 'Echec',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: status == 'sent'
                                      ? const Color(0xFF2ECC71)
                                      : status == 'waiting'
                                          ? const Color(0xFFFFA500)
                                          : const Color(0xFFDC143C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (sendTime != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${sendTime.hour.toString().padLeft(2, '0')}:${sendTime.minute.toString().padLeft(2, '0')}:${sendTime.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${sendTime.day}/${sendTime.month}/${sendTime.year}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                            if (response != null && response.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: status == 'sent'
                                      ? const Color(0xFF2ECC71).withOpacity(0.1)
                                      : const Color(0xFFFFA500)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: 14,
                                      color: status == 'sent'
                                          ? const Color(0xFF2ECC71)
                                          : const Color(0xFFFFA500),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        response,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: status == 'sent'
                                              ? Colors.black87
                                              : const Color(0xFFFFA500),
                                          fontStyle: status == 'waiting'
                                              ? FontStyle.italic
                                              : FontStyle.normal,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentCount = _commands.where((c) => c['status'] == 'sent').length;
    final totalCount = _commands.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configurer ${widget.moduleName}'),
        backgroundColor: const Color(0xFF0C4D7A),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Informations',
          ),
          if (sentCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _showHistoryDialog,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Color(0xFFDC143C), shape: BoxShape.circle),
                    child: Text(
                      '$sentCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/fond tunav.jpg'), fit: BoxFit.cover),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4D7A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ENVOI SUCCESSIF DES COMMANDES',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF0C4D7A)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Numéro téléphone GPS',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                Text(widget.phoneNumber,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: CircularProgressIndicator(
                                          value: totalCount > 0
                                              ? sentCount / totalCount
                                              : 0,
                                          strokeWidth: 8,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Color(0xFF2ECC71)),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        '$sentCount/$totalCount',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSending
                                ? 'Envoi en cours...'
                                : 'Envoi $sentCount/$totalCount',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendAllCommands,
                      icon: const Icon(Icons.send),
                      label: const Text('ENVOYER TOUTES LES COMMANDES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48C9B0),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commandes à envoyer:',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C4D7A)),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _commands.length,
                          itemBuilder: (context, index) {
                            final cmd = _commands[index];
                            final status = cmd['status'];
                            final isSent = status == 'sent';
                            final isWaiting = status == 'waiting';
                            final isSending = status == 'sending';
                            final sendTime = cmd['sendTime'] as DateTime?;
                            final response = cmd['response'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSent
                                    ? const Color(0xFF2ECC71).withOpacity(0.1)
                                    : isWaiting
                                        ? const Color(0xFFFFA500)
                                            .withOpacity(0.1)
                                        : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSent
                                      ? const Color(0xFF2ECC71)
                                      : isWaiting
                                          ? const Color(0xFFFFA500)
                                          : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isSent)
                                        const Icon(Icons.check_circle,
                                            color: Color(0xFF2ECC71), size: 24)
                                      else if (isWaiting || isSending)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFFFA500)),
                                          ),
                                        )
                                      else
                                        Icon(Icons.radio_button_unchecked,
                                            color: Colors.grey[400], size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${index + 1}. ${cmd['command']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                decoration: isSent
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: isSent
                                                    ? Colors.grey
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if (sendTime != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Envoye a ${sendTime.hour.toString().padLeft(2, '0')}:${sendTime.minute.toString().padLeft(2, '0')}:${sendTime.second.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600]),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (response != null &&
                                      response.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSent
                                            ? const Color(0xFF2ECC71)
                                                .withOpacity(0.1)
                                            : const Color(0xFFFFA500)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.reply,
                                            size: 14,
                                            color: isSent
                                                ? const Color(0xFF2ECC71)
                                                : const Color(0xFFFFA500),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              response,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isSent
                                                    ? Colors.black87
                                                    : const Color(0xFFFFA500),
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
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentCommandIndex > 0
                    ? '✓ $sentCount/$totalCount: ${_commands[_currentCommandIndex > 0 ? _currentCommandIndex - 1 : 0]['command']}'
                    : 'Pret a envoyer',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
