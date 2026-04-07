import 'package:flutter/material.dart';
import '../services/ai_diagnostic_service.dart';
import '../utils/app_theme.dart';

class TaskRecommendationsWidget extends StatefulWidget {
  final String taskName;
  final String taskDescription;
  const TaskRecommendationsWidget({
    super.key,
    required this.taskName,
    required this.taskDescription,
  });

  @override
  State<TaskRecommendationsWidget> createState() => _TaskRecommendationsWidgetState();
}

class _TaskRecommendationsWidgetState extends State<TaskRecommendationsWidget> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await AiDiagnosticService.getTaskRecommendations(
      name: widget.taskName,
      description: widget.taskDescription,
    );
    if (mounted) setState(() { _data = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.skyLight));
    }
    if (_data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, size: 40, color: Colors.white24),
          const SizedBox(height: 10),
          Text('Recommandations indisponibles', style: TextStyle(color: AppTheme.c2.withOpacity(0.5))),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: () { setState(() => _loading = true); _load(); },
              icon: const Icon(Icons.refresh, size: 16), label: const Text('Réessayer')),
        ]),
      );
    }

    final tools     = (_data!['tools']     as List?) ?? [];
    final parts     = (_data!['parts']     as List?) ?? [];
    final tutorials = (_data!['tutorials'] as List?) ?? [];
    final duration  = _data!['duration']   as Map?;
    final taskType  = _data!['task_type']  as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type détecté + durée estimée ──
          Row(children: [
            _typeBadge(taskType),
            const Spacer(),
            if (duration != null) _durationBadge(duration),
          ]),
          const SizedBox(height: 14),

          // ── Outils nécessaires ──
          if (tools.isNotEmpty) ...[
            _sectionTitle(Icons.build_outlined, 'Outils nécessaires', AppTheme.skyLight),
            const SizedBox(height: 8),
            _chipWrap(tools.cast<String>(), AppTheme.skyLight),
            const SizedBox(height: 14),
          ],

          // ── Pièces nécessaires ──
          if (parts.isNotEmpty) ...[
            _sectionTitle(Icons.inventory_2_outlined, 'Pièces à prévoir', const Color(0xFFFFB347)),
            const SizedBox(height: 8),
            _chipWrap(parts.cast<String>(), const Color(0xFFFFB347)),
            const SizedBox(height: 14),
          ],

          // ── Tutoriels ──
          if (tutorials.isNotEmpty) ...[
            _sectionTitle(Icons.menu_book_outlined, 'Tutoriels pertinents', AppTheme.c3),
            const SizedBox(height: 8),
            ...tutorials.map((t) => _tutorialTile(t as Map)),
          ],
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    final labels = {
      'installation': ('Installation', Icons.build),
      'maintenance':  ('Maintenance',  Icons.settings),
      'diagnostic':   ('Diagnostic',   Icons.search),
      'configuration':('Configuration',Icons.tune),
      'remplacement': ('Remplacement', Icons.swap_horiz),
      'default':      ('Intervention', Icons.work_outline),
    };
    final info = labels[type] ?? labels['default']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.skyBottom.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.skyBottom.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(info.$2, size: 13, color: AppTheme.skyLight),
        const SizedBox(width: 5),
        Text(info.$1, style: const TextStyle(color: AppTheme.skyLight, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _durationBadge(Map duration) {
    final min    = duration['minutes'] as int? ?? 0;
    final source = duration['source']  as String? ?? '';
    final h = min ~/ 60;
    final m = min % 60;
    final label = h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
    final isHistory = source == 'historique';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF26C6A6).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26C6A6).withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isHistory ? Icons.history : Icons.timer_outlined, size: 13, color: const Color(0xFF26C6A6)),
        const SizedBox(width: 5),
        Text('~$label', style: const TextStyle(color: Color(0xFF26C6A6), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text(isHistory ? '(historique)' : '(estimé)',
            style: TextStyle(color: const Color(0xFF26C6A6).withOpacity(0.6), fontSize: 9)),
      ]),
    );
  }

  Widget _sectionTitle(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    ]);
  }

  Widget _chipWrap(List<String> items, Color color) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(item, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Widget _tutorialTile(Map t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardBlue(radius: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.c3.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_lesson_outlined, size: 16, color: AppTheme.c3),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['title'] as String? ?? '', style: const TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w600)),
            if ((t['module'] as String? ?? '') != 'général')
              Text('Module : ${t['module']}', style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 10)),
          ],
        )),
        Icon(Icons.chevron_right, size: 16, color: AppTheme.c2.withOpacity(0.4)),
      ]),
    );
  }
}
