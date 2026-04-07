import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import '../services/admin_service.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';

class TechnicianTasksScreen extends StatefulWidget {
  final Map<String, dynamic> technician;
  const TechnicianTasksScreen({super.key, required this.technician});

  @override
  State<TechnicianTasksScreen> createState() => _TechnicianTasksScreenState();
}

class _TechnicianTasksScreenState extends State<TechnicianTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  String _filter = 'Tous';

  int get _userId   => widget.technician['id'] as int;
  String get _username => widget.technician['username'] as String;
  String? get _odooId  => widget.technician['odoo_user_id'] as String?;

  static const _stages = ['Tous', 'New', 'In Progress', 'Planifié', 'Done', 'Cancelled', 'Awaiting'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    // 1. API Odoo helpdesk filtrée par assigned_to_id
    final helpdesk = await AdminService.getHelpdeskTasks(odooUserId: _odooId);
    if (helpdesk.isNotEmpty) {
      if (mounted) setState(() { _tasks = helpdesk; _loading = false; });
      return;
    }

    // 2. Fallback API locale
    try {
      final local = await AdminService.getTechnicianTasks(_userId);
      if (mounted) setState(() { _tasks = local; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'Tous') return _tasks;
    return _tasks.where((t) {
      final s = (t['stage'] ?? t['status'] ?? '') as String;
      return s.toLowerCase() == _filter.toLowerCase();
    }).toList();
  }

  // ── Helpers champs API ─────────────────────────────────────────────────────
  String _name(Map t)   => (t['subject'] ?? t['name'] ?? '') as String;
  String _stage(Map t)  => (t['stage']   ?? t['status'] ?? 'New') as String;
  String _date(Map t)   => ((t['created_at'] ?? '') as String).split(' ').first;
  String _assignee(Map t) => (t['assigned_to'] ?? '') as String;

  String _cleanDesc(Map t) {
    final raw = (t['description'] ?? '') as String;
    if (raw.isEmpty) return '';
    try {
      final text = parse(raw).body?.text?.trim() ?? raw;
      return text.length > 120 ? '${text.substring(0, 120)}…' : text;
    } catch (_) { return raw.length > 120 ? '${raw.substring(0, 120)}…' : raw; }
  }

  Color _stageColor(String s) {
    switch (s.toLowerCase()) {
      case 'done':        return const Color(0xFF26C6A6);
      case 'in progress': return const Color(0xFFFFB347);
      case 'planifié':    return const Color(0xFFFFB347);
      case 'new':         return AppTheme.skyLight;
      case 'cancelled':   return Colors.red;
      case 'awaiting':    return const Color(0xFFAB47BC);
      default:            return AppTheme.skyBottom;
    }
  }

  String _stageLabel(String s) {
    switch (s.toLowerCase()) {
      case 'done':        return 'TERMINÉ';
      case 'in progress': return 'EN COURS';
      case 'planifié':    return 'PLANIFIÉ';
      case 'new':         return 'NOUVEAU';
      case 'cancelled':   return 'ANNULÉ';
      case 'awaiting':    return 'EN ATTENTE';
      default:            return s.toUpperCase();
    }
  }

  IconData _stageIcon(String s) {
    switch (s.toLowerCase()) {
      case 'done':        return Icons.check_circle_rounded;
      case 'in progress': return Icons.timelapse_rounded;
      case 'planifié':    return Icons.schedule;
      case 'new':         return Icons.fiber_new_rounded;
      case 'cancelled':   return Icons.cancel_outlined;
      case 'awaiting':    return Icons.hourglass_top_rounded;
      default:            return Icons.task_alt;
    }
  }

  // ── Changement de stage (admin) ────────────────────────────────────────────
  Future<void> _changeStage(Map<String, dynamic> task, String stageKey) async {
    await TaskService().updateStage(task['id'].toString(), stageKey);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Statut mis à jour ✓'), backgroundColor: Colors.green));
  }

  PopupMenuItem<String> _menuItem(String key, IconData icon, String label, Color color) =>
      PopupMenuItem<String>(
        value: key,
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ]),
      );

  // ── Dialogue détail tâche ──────────────────────────────────────────────────
  void _showDetail(Map<String, dynamic> task) {
    final stage = _stage(task);
    final color = _stageColor(stage);
    final desc  = (task['description'] ?? '') as String;
    String cleanFull = '';
    try { cleanFull = parse(desc).body?.text?.trim() ?? desc; } catch (_) { cleanFull = desc; }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.3,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(18), children: [
          // Handle
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppTheme.c2.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          // Titre
          Text(_name(task), style: const TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Badges
          Wrap(spacing: 8, children: [
            _badge(_stageLabel(stage), color),
            _badge('#${task['id']}', AppTheme.skyLight),
            if (_assignee(task).isNotEmpty) _badge(_assignee(task), AppTheme.c3),
            _badge(_date(task), AppTheme.c2),
          ]),
          const SizedBox(height: 14),
          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.skyTop.withOpacity(0.4)),
            ),
            child: Text(
              cleanFull.isNotEmpty ? cleanFull : 'Aucune description',
              style: const TextStyle(color: AppTheme.c2, fontSize: 12, height: 1.5),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(child: Column(children: [
          // ── AppBar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppTheme.darkTopbar.withOpacity(0.8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.c1),
                  onPressed: () => Navigator.pop(context)),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: AppTheme.skyBottom.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9)),
                child: Center(child: Text(_username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppTheme.skyBottom, fontWeight: FontWeight.bold, fontSize: 15))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_username, style: const TextStyle(color: AppTheme.c1, fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${_tasks.length} ticket(s) • ${_odooId != null ? 'ID Odoo: $_odooId' : 'ID Odoo non défini'}',
                    style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 10)),
              ])),
              IconButton(icon: const Icon(Icons.refresh, color: AppTheme.c1), onPressed: _load),
            ]),
          ),

          // ── Filtre par stage ──
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _stages.length,
              itemBuilder: (_, i) {
                final s = _stages[i];
                final sel = _filter == s;
                final count = s == 'Tous' ? _tasks.length
                    : _tasks.where((t) => (_stage(t)).toLowerCase() == s.toLowerCase()).length;
                return GestureDetector(
                  onTap: () => setState(() => _filter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: sel ? _stageColor(s) : AppTheme.darkCard.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? _stageColor(s) : AppTheme.skyTop.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s == 'Tous' ? 'Tous' : _stageLabel(s),
                          style: TextStyle(color: sel ? Colors.white : AppTheme.c2,
                              fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: sel ? Colors.white.withOpacity(0.25) : AppTheme.skyTop.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count', style: TextStyle(
                            color: sel ? Colors.white : AppTheme.c2, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),

          // ── Liste ──
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.skyBottom))
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: AppTheme.c2, fontSize: 12)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ]))
                  : filtered.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inbox_outlined, size: 48, color: AppTheme.c2.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          Text('Aucun ticket $_filter', style: TextStyle(color: AppTheme.c2.withOpacity(0.5))),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _taskCard(filtered[i]),
                        ),
          ),
        ])),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final stage = _stage(task);
    final color = _stageColor(stage);
    final desc  = _cleanDesc(task);

    return GestureDetector(
      onTap: () => _showDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: AppTheme.cardBlue(radius: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icône statut
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(_stageIcon(stage), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Contenu
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name(task),
                style: const TextStyle(color: AppTheme.c1, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              // Badge stage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(_stageLabel(stage),
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              // ID
              Text('#${task['id']}', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 10)),
              const SizedBox(width: 6),
              // Date
              Icon(Icons.calendar_today_outlined, size: 10, color: AppTheme.c2.withOpacity(0.4)),
              const SizedBox(width: 3),
              Text(_date(task), style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 10)),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(desc, style: TextStyle(color: AppTheme.c2.withOpacity(0.65), fontSize: 11, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (_assignee(task).isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.person_outline, size: 11, color: AppTheme.c3.withOpacity(0.7)),
                const SizedBox(width: 3),
                Text(_assignee(task), style: TextStyle(color: AppTheme.c3.withOpacity(0.8), fontSize: 10)),
              ]),
            ],
          ])),
          // Menu admin
          PopupMenuButton<String>(
            icon: Icon(Icons.tune, color: AppTheme.skyLight.withOpacity(0.7), size: 18),
            color: AppTheme.darkCard,
            tooltip: 'Changer statut',
            onSelected: (key) => _changeStage(task, key),
            itemBuilder: (_) => [
              _menuItem('a_faire', Icons.fiber_new_rounded,  'Nouveau', AppTheme.skyBottom),
              _menuItem('annule',  Icons.cancel_outlined,    'Annulé',  Colors.red),
            ],
          ),
        ]),
      ),
    );
  }
}
