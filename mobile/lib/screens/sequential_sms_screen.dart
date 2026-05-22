import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:telephony/telephony.dart';
import '../utils/config.dart' as AppConfig;

enum _St { pending, sending, waitingReply, confirmed, failed }

enum _SmsPhase { idle, sending, waitingReply, done }

class _Cmd {
  final String text;
  _St status = _St.pending;
  String? response;
  DateTime? sentAt;
  _Cmd(this.text);
}

class SequentialSmsScreen extends StatefulWidget {
  final String phoneNumber;
  final String moduleName;
  const SequentialSmsScreen({
    super.key,
    required this.phoneNumber,
    required this.moduleName,
  });
  @override
  State<SequentialSmsScreen> createState() => _SState();
}

class _SState extends State<SequentialSmsScreen> {
  static const _raw = [
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

  late final List<_Cmd> _cmds;

  final _tel = Telephony.instance;
  bool _listening = false;

  _SmsPhase _phase = _SmsPhase.idle;
  int _idx = 0;

  Timer? _replyTimer;
  Timer? _pollTimer;

  static const int _maxAttempts = 2;
  static const int _replyTimeoutS = 60;
  int _attemptCount = 0;

  int? _lastMsgDate;

  @override
  void initState() {
    super.initState();
    _cmds = _raw.map(_Cmd.new).toList();
    _restoreState();
    _requestSmsPermission();
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── RESTAURATION D'ÉTAT ──────────────────────────────────────────────────
  Future<void> _restoreState() async {
    try {
      final saved =
          await AppConfig.Config.loadModuleCommands(widget.moduleName);
      if (saved == null) return;
      final list = List<Map<String, dynamic>>.from(saved['commands'] as List);
      for (int i = 0; i < _cmds.length && i < list.length; i++) {
        final s = list[i];
        if (s['command'] != _cmds[i].text) continue;
        switch (s['status'] as String? ?? 'pending') {
          case 'confirmed':
            _cmds[i].status = _St.confirmed;
            break;
          case 'failed':
            _cmds[i].status = _St.failed;
            break;
          default:
            _cmds[i].status = _St.pending;
        }
        _cmds[i].response = s['response'] as String?;
        final st = s['sentAt'];
        if (st != null) _cmds[i].sentAt = DateTime.tryParse(st.toString());
      }
      final done = _cmds.where((c) => c.status == _St.confirmed).length;
      if (done > 0 && mounted) {
        _toast('Reprise : $done/${_cmds.length} déjà confirmées',
            const Color(0xFF3498DB));
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _saveState() async {
    await AppConfig.Config.saveModuleCommands(
      widget.moduleName,
      _cmds
          .map((c) => {
                'command': c.text,
                'status': c.status.name,
                'response': c.response,
                'sentAt': c.sentAt?.toIso8601String(),
              })
          .toList(),
      _cmds
          .indexWhere((c) => c.status == _St.pending || c.status == _St.failed),
    );
  }

  // ── PERMISSIONS + LISTENER ───────────────────────────────────────────────
  Future<void> _requestSmsPermission() async {
    try {
      final ok = await _tel.requestSmsPermissions;
      if (ok == true) {
        _startListening();
      } else {
        _toast('Permission SMS refusée – réponses non détectées',
            const Color(0xFFFFA500),
            dur: 5);
      }
    } catch (_) {}
  }

  void _startListening() {
    if (_listening) return;
    _tel.listenIncomingSms(onNewMessage: _onSms, listenInBackground: false);
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollInbox());
    setState(() => _listening = true);
  }

  // ── RÉCEPTION SMS ────────────────────────────────────────────────────────
  void _onSms(SmsMessage msg) {
    final body = msg.body ?? '';
    final sender = msg.address ?? '';
    if (body.isEmpty) return;
    if (_phase != _SmsPhase.waitingReply) return;
    final normSender = _norm(sender);
    final normPhone = _norm(widget.phoneNumber);
    if (normSender.isEmpty || normPhone.isEmpty) {
      if (sender.trim() != widget.phoneNumber.trim()) return;
    } else if (!normSender.endsWith(normPhone) &&
        !normPhone.endsWith(normSender)) {
      return;
    }
    _gpsConfirmed(body);
  }

  Future<void> _pollInbox() async {
    if (_phase != _SmsPhase.waitingReply) return;
    try {
      final msgs = await _tel.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      if (msgs.isEmpty) return;
      for (final m in msgs.take(20)) {
        final d = m.date ?? 0;
        if (d <= (_lastMsgDate ?? 0)) break;
        final sender = m.address ?? '';
        final normSender = _norm(sender);
        final normPhone = _norm(widget.phoneNumber);
        final match = normSender.isNotEmpty && normPhone.isNotEmpty
            ? normSender.endsWith(normPhone) || normPhone.endsWith(normSender)
            : sender.trim() == widget.phoneNumber.trim();
        if (match) {
          _lastMsgDate = d;
          _onSms(m);
          break;
        }
      }
    } catch (_) {}
  }

  // ── GPS A RÉPONDU ────────────────────────────────────────────────────────
  void _gpsConfirmed(String body) {
    _replyTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _cmds[_idx].status = _St.confirmed;
      _cmds[_idx].response = body;
      _phase = _SmsPhase.idle;
      _attemptCount = 0;
    });
    _toast('Réponse GPS : $body', const Color(0xFF2ECC71), dur: 10);
    _saveState();
    Future.delayed(const Duration(milliseconds: 800), _sendNext);
  }

  // ── TIMEOUT → 2ème essai ou passer à la suivante ─────────────────────────
  void _onReplyTimeout() {
    if (!mounted || _phase != _SmsPhase.waitingReply) return;

    if (_attemptCount < _maxAttempts) {
      _toast(
        'Pas de réponse (essai $_attemptCount/$_maxAttempts) – nouvel essai…',
        const Color(0xFFFFA500),
        dur: 3,
      );
      setState(() {
        _cmds[_idx].response = 'Essai $_attemptCount raté – nouvel envoi…';
      });
      _sendCommand(_idx);
    } else {
      // Tous les essais épuisés → marquer échec et passer à la suivante
      setState(() {
        _cmds[_idx].status = _St.failed;
        _cmds[_idx].response = 'Pas de réponse GPS après $_maxAttempts essais';
        _phase = _SmsPhase.idle;
        _attemptCount = 0;
      });
      _saveState();
      _toast(
        'Cmd ${_idx + 1} sans réponse – passage à la suivante…',
        const Color(0xFFFFA500),
        dur: 3,
      );
      Future.delayed(const Duration(milliseconds: 800), _sendNext);
    }
  }

  // ── BOUTON PRINCIPAL ─────────────────────────────────────────────────────
  void _startSequence() {
    if (_phase != _SmsPhase.idle) return;
    final first = _cmds
        .indexWhere((c) => c.status == _St.pending || c.status == _St.failed);
    if (first < 0) {
      _toast('Toutes les commandes déjà confirmées', const Color(0xFF2ECC71));
      return;
    }
    _idx = first;
    _attemptCount = 0;
    _sendCommand(_idx);
  }

  void _sendNext() {
    if (!mounted) return;
    int next = _cmds.indexWhere(
      (c) => c.status == _St.pending || c.status == _St.failed,
      _idx + 1,
    );
    if (next < 0) {
      next = _cmds
          .indexWhere((c) => c.status == _St.pending || c.status == _St.failed);
    }
    if (next < 0) {
      setState(() => _phase = _SmsPhase.done);
      _saveState();
      _toast('Toutes les commandes envoyées !', const Color(0xFF2ECC71),
          dur: 6);
      return;
    }
    _idx = next;
    _attemptCount = 0;
    _sendCommand(_idx);
  }

  // ── ENVOYER LA COMMANDE À L'INDEX i ──────────────────────────────────────
  Future<void> _sendCommand(int i) async {
    if (!mounted) return;

    _attemptCount++;

    setState(() {
      _phase = _SmsPhase.sending;
      _cmds[i].status = _St.sending;
      _cmds[i].sentAt = DateTime.now();
      _cmds[i].response = null;
    });

    _lastMsgDate = DateTime.now().millisecondsSinceEpoch;

    try {
      await Future.any([
        _tel.sendSms(to: widget.phoneNumber, message: _cmds[i].text),
        Future.delayed(const Duration(seconds: 6)),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cmds[i].status = _St.failed;
          _cmds[i].response = 'Erreur envoi: $e';
          _phase = _SmsPhase.idle;
          _attemptCount = 0;
        });
        _saveState();
        _toast('Erreur envoi cmd ${i + 1} – passage à la suivante…',
            const Color(0xFFDC143C),
            dur: 3);
        Future.delayed(const Duration(milliseconds: 800), _sendNext);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _phase = _SmsPhase.waitingReply;
      _cmds[i].status = _St.waitingReply;
      _cmds[i].response =
          'Tentative $_attemptCount/$_maxAttempts – attente réponse GPS ($_replyTimeoutS s)…';
    });

    _toast('Envoyé (essai $_attemptCount/$_maxAttempts) : ${_cmds[i].text}',
        const Color(0xFF3498DB),
        dur: 2);

    _replyTimer?.cancel();
    _replyTimer = Timer(Duration(seconds: _replyTimeoutS), _onReplyTimeout);
  }

  // ── UTILITAIRES ──────────────────────────────────────────────────────────
  String _norm(String n) {
    final t = n.trim();
    return t.startsWith('+')
        ? '+${t.substring(1).replaceAll(RegExp(r'\D'), '')}'
        : t.replaceAll(RegExp(r'\D'), '');
  }

  void _toast(String msg, Color bg, {int dur = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style:
              const TextStyle(color: AppTheme.c1, fontWeight: FontWeight.w500)),
      backgroundColor: bg,
      duration: Duration(seconds: dur),
    ));
  }

  // ── DIALOG HISTORIQUE ────────────────────────────────────────────────────
  void _showHistory() {
    final done = _cmds.where((c) => c.status != _St.pending).toList();
    if (done.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.skyMid.withOpacity(0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Expanded(
                  child: Text('Historique',
                      style: TextStyle(
                          color: AppTheme.c1,
                          fontSize: 17,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.c1),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              itemCount: done.length,
              itemBuilder: (_, i) {
                final c = done[i];
                final col = _colFor(c.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyMid.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: col.withOpacity(0.4), width: 1.2),
                  ),
                  child: ListTile(
                    leading: Icon(_iconFor(c.status), color: col),
                    title: Text(c.text,
                        style: TextStyle(
                            color: AppTheme.c1,
                            fontWeight: FontWeight.bold,
                            decoration: c.status == _St.confirmed
                                ? TextDecoration.lineThrough
                                : null)),
                    subtitle: c.response != null
                        ? Text(c.response!,
                            style: TextStyle(color: AppTheme.c2))
                        : null,
                    trailing: _badge(_labelFor(c.status), col),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
        child: Text(t,
            style:
                TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );

  Color _colFor(_St s) {
    switch (s) {
      case _St.confirmed:
        return const Color(0xFF2ECC71);
      case _St.waitingReply:
        return const Color(0xFFFFA500);
      case _St.failed:
        return const Color(0xFFDC143C);
      default:
        return Colors.grey;
    }
  }

  IconData _iconFor(_St s) {
    switch (s) {
      case _St.confirmed:
        return Icons.check_circle;
      case _St.waitingReply:
        return Icons.hourglass_empty;
      case _St.failed:
        return Icons.error;
      default:
        return Icons.circle_outlined;
    }
  }

  String _labelFor(_St s) {
    switch (s) {
      case _St.confirmed:
        return 'Confirmé';
      case _St.sending:
        return 'Envoi…';
      case _St.waitingReply:
        return 'Attente';
      case _St.failed:
        return 'Échec';
      default:
        return 'En attente';
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final confirmed = _cmds.where((c) => c.status == _St.confirmed).length;
    final total = _cmds.length;
    final allDone = confirmed == total;
    final nextPend = _cmds.indexWhere((c) => c.status != _St.confirmed);
    final canStart = _phase == _SmsPhase.idle && !allDone;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configurer ${widget.moduleName}'),
        backgroundColor: Colors.transparent,
        actions: [
          if (confirmed > 0)
            Stack(children: [
              IconButton(
                  icon: const Icon(Icons.history), onPressed: _showHistory),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Color(0xFFDC143C), shape: BoxShape.circle),
                  child: Text('$confirmed',
                      style: const TextStyle(
                          color: AppTheme.c1,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/fond tunav.jpg'), fit: BoxFit.cover),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── CARTE SUPÉRIEURE ──────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.cardBlue(radius: 16),
              child: Column(children: [
                const Text('ENVOI SUCCESSIF DES COMMANDES',
                    style: TextStyle(
                        color: AppTheme.c1,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4)),
                const SizedBox(height: 14),

                // Numéro GPS
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppTheme.c1,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.phone_android, color: Color(0xFF0C4D7A)),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Numéro GPS',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 11)),
                          Text(widget.phoneNumber,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ]),
                  ]),
                ),
                const SizedBox(height: 12),

                // Progression
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppTheme.c1,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    SizedBox(
                      width: 66,
                      height: 66,
                      child: Stack(children: [
                        CircularProgressIndicator(
                          value: total > 0 ? confirmed / total : 0,
                          strokeWidth: 7,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(allDone
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFF48C9B0)),
                        ),
                        Center(
                          child: Text('$confirmed/$total',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allDone
                                  ? 'Terminé ✓'
                                  : (_phase == _SmsPhase.sending ||
                                          _phase == _SmsPhase.waitingReply)
                                      ? 'Essai $_attemptCount/$_maxAttempts en cours…'
                                      : 'Prêt à envoyer',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87),
                            ),
                            if (!allDone && nextPend >= 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text('Cmd ${nextPend + 1} / $total',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── BOUTON ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canStart ? _startSequence : null,
                    icon: Icon(confirmed > 0 && !allDone
                        ? Icons.play_arrow
                        : Icons.send),
                    label: Text(
                      allDone
                          ? 'TERMINÉ ✓'
                          : (_phase == _SmsPhase.sending ||
                                  _phase == _SmsPhase.waitingReply)
                              ? 'Essai $_attemptCount/$_maxAttempts en cours…'
                              : confirmed > 0
                                  ? 'REPRENDRE (cmd ${nextPend + 1})'
                                  : 'ENVOYER TOUTES LES COMMANDES',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          allDone ? Colors.grey[400] : const Color(0xFF48C9B0),
                      foregroundColor: AppTheme.c1,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),

            // ── LISTE DES COMMANDES ───────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                decoration: AppTheme.cardBlue(radius: 22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commandes à envoyer :',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C4D7A))),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _cmds.length,
                          itemBuilder: (_, i) => _tile(i),
                        ),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
      ),

      // ── BARRE BAS ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: allDone ? const Color(0xFF2ECC71) : const Color(0xFF0C4D7A),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(children: [
          Icon(allDone ? Icons.check_circle : Icons.info_outline,
              color: AppTheme.c1),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              allDone
                  ? '$confirmed/$total commandes confirmées ✓'
                  : (_phase == _SmsPhase.sending ||
                          _phase == _SmsPhase.waitingReply)
                      ? 'Cmd ${_idx + 1}/$total – essai $_attemptCount/$_maxAttempts'
                      : 'Prêt – $confirmed/$total confirmées',
              style: const TextStyle(
                  color: AppTheme.c1, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),
    );
  }

  // ── TUILE D'UNE COMMANDE ─────────────────────────────────────────────────
  Widget _tile(int i) {
    final c = _cmds[i];
    Color border;
    Color bg;
    Widget ico;

    switch (c.status) {
      case _St.confirmed:
        border = const Color(0xFF2ECC71);
        bg = const Color(0xFF2ECC71).withOpacity(0.07);
        ico =
            const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 22);
        break;
      case _St.sending:
      case _St.waitingReply:
        border = const Color(0xFFFFA500);
        bg = const Color(0xFFFFA500).withOpacity(0.07);
        ico = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA500))));
        break;
      case _St.failed:
        border = const Color(0xFFDC143C);
        bg = const Color(0xFFDC143C).withOpacity(0.05);
        ico = const Icon(Icons.error, color: Color(0xFFDC143C), size: 22);
        break;
      default:
        border = AppTheme.skyBottom.withOpacity(0.4);
        bg = AppTheme.skyMid.withOpacity(0.15);
        ico = Icon(Icons.radio_button_unchecked,
            color: AppTheme.c2.withOpacity(0.6), size: 22);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ico,
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${i + 1}. ${c.text}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.status == _St.confirmed ? AppTheme.c2 : AppTheme.c1,
                  decoration: c.status == _St.confirmed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (c.sentAt != null)
                Text(
                  'Envoyé '
                  '${c.sentAt!.hour.toString().padLeft(2, '0')}:'
                  '${c.sentAt!.minute.toString().padLeft(2, '0')}:'
                  '${c.sentAt!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.c2),
                ),
            ]),
          ),
        ]),
        if (c.response != null && c.response!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppTheme.skyMid.withOpacity(0.2),
                borderRadius: BorderRadius.circular(5)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.reply, size: 13, color: border),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  c.response!,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.status == _St.confirmed ? AppTheme.c2 : border,
                    fontStyle: c.status == _St.waitingReply
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
