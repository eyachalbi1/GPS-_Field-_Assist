import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class _Message {
  final String text;
  final bool isUser;
  final List<dynamic> sources;
  _Message({required this.text, required this.isUser, this.sources = const []});

  Map<String, dynamic> toJson() => {
    'text': text, 'isUser': isUser,
    'sources': sources,
  };

  factory _Message.fromJson(Map<String, dynamic> j) => _Message(
    text: j['text'] as String,
    isUser: j['isUser'] as bool,
    sources: (j['sources'] as List?) ?? [],
  );
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _loading = false;

  static const _prefsKey = 'chat_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        setState(() {
          _messages.addAll(list.map((e) => _Message.fromJson(e as Map<String, dynamic>)));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return;
      } catch (_) {}
    }
    // Première ouverture
    setState(() {
      _messages.add(_Message(
        text: 'Bonjour ! Posez-moi une question sur les manuels GPS disponibles.',
        isUser: false,
      ));
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(_prefsKey, json);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    setState(() {
      _messages.clear();
      _messages.add(_Message(
        text: 'Bonjour ! Posez-moi une question sur les manuels GPS disponibles.',
        isUser: false,
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Message(text: question, isUser: true));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final result = await AiService.ask(question);

    setState(() {
      _loading = false;
      if (result == null) {
        _messages.add(_Message(
          text: 'Erreur de connexion au serveur. Vérifiez votre réseau.',
          isUser: false,
        ));
      } else {
        final answer = result['answer'] as String? ?? 'Aucune réponse.';
        final sources = result['sources'] as List? ?? [];
        _messages.add(_Message(text: answer, isUser: false, sources: sources));
      }
    });
    _saveHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/ICON_CHATBOT.png'),
              backgroundColor: Colors.transparent,
            ),
            SizedBox(width: 8),
            Text('Assistant PDF'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Effacer la conversation',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.card(false),
                  title: const Text('Effacer', style: TextStyle(color: Colors.white)),
                  content: const Text('Supprimer toute la conversation ?', style: TextStyle(color: AppTheme.c2)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: AppTheme.c2.withOpacity(0.7)))),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Effacer')),
                  ],
                ),
              );
              if (ok == true) _clearHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Réindexer les PDFs',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Réindexation en cours...')),
              );
              final ok = await AiService.reindex();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Index mis à jour ✓' : 'Échec de la réindexation'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) return _buildTyping();
                  return _buildBubble(_messages[index]);
                },
              ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_Message msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              const CircleAvatar(
                radius: 16,
                backgroundImage: AssetImage('assets/ICON_CHATBOT.png'),
                backgroundColor: Colors.transparent,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF0066FF)
                          : const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(color: AppTheme.c1, fontSize: 14, height: 1.4),
                    ),
                  ),
                  if (msg.sources.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: msg.sources.map((s) {
                        final src = s as Map<String, dynamic>;
                        final name = (src['filename'] as String)
                            .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
                        final score = ((src['score'] as num) * 100).toStringAsFixed(0);
                        return Chip(
                          label: Text('$name · $score%',
                              style: const TextStyle(fontSize: 10, color: AppTheme.c2)),
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 40,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Dot(delay: 0),
              _Dot(delay: 150),
              _Dot(delay: 300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    final isDark = false;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
      color: AppTheme.bg(isDark),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: AppTheme.text(isDark)),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Posez une question sur les manuels...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: const Color(0xFF1E2E3E),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF0066FF),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.send, color: AppTheme.c1, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(widget.delay / 600, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: CircleAvatar(radius: 4, backgroundColor: AppTheme.c2.withOpacity(0.7)),
    );
  }
}



