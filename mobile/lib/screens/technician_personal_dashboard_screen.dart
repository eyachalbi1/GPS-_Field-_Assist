import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class TechnicianPersonalDashboardScreen extends StatefulWidget {
  final Map tech;
  const TechnicianPersonalDashboardScreen({super.key, required this.tech});

  @override
  State<TechnicianPersonalDashboardScreen> createState() =>
      _TechnicianPersonalDashboardScreenState();
}

class _TechnicianPersonalDashboardScreenState
    extends State<TechnicianPersonalDashboardScreen> {
  String _period = 'week';

  String _fmt(int? min) {
    if (min == null) return '—';
    final h = min ~/ 60; final m = min % 60;
    return h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
  }

  Color _scoreColor(double s) =>
      s >= 4 ? const Color(0xFF26C6A6) : s >= 2.5 ? const Color(0xFFFFB347) : const Color(0xFFFF4444);

  String _periodLabel() {
    switch (_period) {
      case 'day':   return 'Aujourd\'hui';
      case 'week':  return 'Cette semaine';
      case 'month': return 'Ce mois';
      default:      return 'Total';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tech      = widget.tech;
    final username  = tech['username'] as String;
    final score     = (tech['score'] as num?)?.toDouble() ?? 0.0;
    final total     = tech['total_tasks']      as int? ?? 0;
    final completed = tech['completed_tasks']  as int? ?? 0;
    final avgMin    = tech['avg_duration_min'] as int?;
    final color     = _scoreColor(score);
    final periods   = (tech['periods'] as Map?) ?? {};
    final pd        = (periods[_period] as Map?) ?? {};
    final pdDone    = pd['done']    as int? ?? 0;
    final pdTotal   = pd['total']   as int? ?? 0;
    final pdAvg     = pd['avg_min'] as int?;
    final rate      = total > 0 ? completed / total : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTopbar.withOpacity(0.95),
        title: Row(children: [
          _avatar(username, color, size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(username, style: const TextStyle(color: AppTheme.c1, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Tableau de bord personnel', style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 11)),
          ]),
        ]),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: ListView(padding: const EdgeInsets.all(14), children: [

          // ── Score global ──────────────────────────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _secHeader(Icons.star_rounded, 'Score de performance', const Color(0xFFFFB347)),
            const SizedBox(height: 14),
            Row(children: [
              // Cercle score
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                  color: color.withOpacity(0.1),
                ),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$score', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('/5', style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
                ])),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _labeledBar('Score global', '${(score / 5 * 100).toStringAsFixed(0)}%', score / 5, color),
                const SizedBox(height: 8),
                _labeledBar('Complétion', '$completed/$total', rate, const Color(0xFF26C6A6)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 12, color: AppTheme.c2),
                  const SizedBox(width: 4),
                  Text('Durée moy. globale : ${_fmt(avgMin)}',
                      style: const TextStyle(color: AppTheme.c2, fontSize: 11)),
                ]),
              ])),
            ]),
          ])),
          const SizedBox(height: 12),

          // ── Sélecteur période ─────────────────────────────────────────────
          _periodSelector(),
          const SizedBox(height: 12),

          // ── Stats période ─────────────────────────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _secHeader(Icons.event_note, 'Activité — ${_periodLabel()}', const Color(0xFF26C6A6)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _bigStat('$pdDone', 'Terminées', const Color(0xFF26C6A6))),
              _vDiv(),
              Expanded(child: _bigStat('$pdTotal', 'Total', AppTheme.skyLight)),
              _vDiv(),
              Expanded(child: _bigStat(_fmt(pdAvg), 'Moy. durée', const Color(0xFFFFB347))),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(
              value: pdTotal > 0 ? pdDone / pdTotal : 0.0,
              minHeight: 10,
              backgroundColor: AppTheme.skyTop.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF26C6A6)),
            )),
            const SizedBox(height: 6),
            Text(
              pdTotal > 0
                  ? '${(pdDone / pdTotal * 100).toStringAsFixed(0)}% des tâches terminées ${_periodLabel().toLowerCase()}'
                  : 'Aucune tâche ${_periodLabel().toLowerCase()}',
              style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 11),
            ),
          ])),
          const SizedBox(height: 12),

          // ── Comparaison 3 périodes ────────────────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _secHeader(Icons.compare_arrows, 'Comparaison des périodes', AppTheme.skyLight),
            const SizedBox(height: 12),
            _compareTable(periods),
          ])),
          const SizedBox(height: 12),

          // ── Chips résumé ──────────────────────────────────────────────────
          _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _secHeader(Icons.summarize_outlined, 'Résumé global', AppTheme.c3),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(Icons.task_alt,       '$completed',          'terminées',  const Color(0xFF26C6A6)),
              _chip(Icons.pending_outlined,'${total - completed}','en attente', const Color(0xFFFFB347)),
              _chip(Icons.assignment,     '$total',              'total',       AppTheme.skyLight),
              _chip(Icons.timer_outlined, _fmt(avgMin),          'moy. durée',  AppTheme.c3),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _compareTable(Map periods) {
    final rows = [
      ('Aujourd\'hui', 'day',   AppTheme.skyLight),
      ('Semaine',      'week',  const Color(0xFF26C6A6)),
      ('Mois',         'month', const Color(0xFFFFB347)),
    ];
    return Column(children: rows.map((r) {
      final pd    = (periods[r.$2] as Map?) ?? {};
      final done  = pd['done']    as int? ?? 0;
      final total = pd['total']   as int? ?? 0;
      final avg   = pd['avg_min'] as int?;
      final rate  = total > 0 ? done / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(width: 82, child: Text(r.$1,
              style: TextStyle(color: r.$3, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate, minHeight: 8,
              backgroundColor: AppTheme.skyTop.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(r.$3),
            ),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 28, child: Text('$done',
              style: TextStyle(color: r.$3, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          Text('/$total', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11)),
          const SizedBox(width: 8),
          SizedBox(width: 42, child: Text(_fmt(avg),
              style: TextStyle(color: AppTheme.c2, fontSize: 10), textAlign: TextAlign.right)),
        ]),
      );
    }).toList());
  }

  Widget _periodSelector() {
    const periods = {'day': 'Jour', 'week': 'Semaine', 'month': 'Mois', 'all': 'Tout'};
    return Row(children: periods.entries.map((e) {
      final sel = _period == e.key;
      return Expanded(child: GestureDetector(
        onTap: () => setState(() => _period = e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF26C6A6) : AppTheme.darkCard.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? const Color(0xFF26C6A6) : AppTheme.skyTop.withOpacity(0.3)),
          ),
          child: Text(e.value, textAlign: TextAlign.center,
            style: TextStyle(color: sel ? Colors.white : AppTheme.c2,
                fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ),
      ));
    }).toList());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14), decoration: AppTheme.cardBlue(radius: 16), child: child);

  Widget _secHeader(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 14, color: color), const SizedBox(width: 6),
    Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
  ]);

  Widget _bigStat(String v, String l, Color c) => Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(l, style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 10), textAlign: TextAlign.center),
  ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: AppTheme.skyTop.withOpacity(0.3));

  Widget _labeledBar(String label, String right, double value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.c2, fontSize: 10)),
        const Spacer(),
        Text(right, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0), minHeight: 6,
        backgroundColor: AppTheme.skyTop.withOpacity(0.25),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      )),
    ],
  );

  Widget _avatar(String u, Color c, {double size = 34}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(size / 3)),
    child: Center(child: Text(u.substring(0, 1).toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: size * 0.44))),
  );

  Widget _chip(IconData icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 4),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 9)),
    ]),
  );
}
