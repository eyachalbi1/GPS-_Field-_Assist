import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../utils/app_theme.dart';
import 'technician_personal_dashboard_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  late TabController _tab;

  // Période sélectionnée : 'day' | 'week' | 'month' | 'all'
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await AdminService.getDashboard();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(int? min) {
    if (min == null) return '—';
    final h = min ~/ 60; final m = min % 60;
    return h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
  }

  Color _scoreColor(double s) =>
      s >= 4 ? const Color(0xFF26C6A6) : s >= 2.5 ? const Color(0xFFFFB347) : const Color(0xFFFF4444);

  Map _periodData(Map src) => (src['periods']?[_period] as Map?) ?? {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTopbar.withOpacity(0.95),
        title: const Row(children: [
          Icon(Icons.dashboard_outlined, color: Color(0xFF26C6A6), size: 20),
          SizedBox(width: 8),
          Text('Dashboard', style: TextStyle(color: AppTheme.c1, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.c1), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF26C6A6),
          labelColor: const Color(0xFF26C6A6),
          unselectedLabelColor: AppTheme.c2,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Vue globale'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Techniciens'),
            Tab(icon: Icon(Icons.leaderboard, size: 18), text: 'Classement'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF26C6A6)))
            : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tab,
                    children: [
                      _buildGlobalTab(),
                      _buildTechniciansTab(),
                      _buildRankingTab(),
                    ],
                  ),
      ),
    );
  }

  // ── Erreur ─────────────────────────────────────────────────────────────────
  Widget _buildError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: Colors.red, size: 48),
    const SizedBox(height: 10),
    Text(_error!, style: const TextStyle(color: AppTheme.c2)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
  ]));

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — Vue globale
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGlobalTab() {
    final d          = _data!;
    final totalTechs = d['total_technicians'] as int? ?? 0;
    final totalAll   = d['total_tasks']       as int? ?? 0;
    final doneAll    = d['completed_tasks']   as int? ?? 0;
    final pendAll    = d['pending_tasks']     as int? ?? 0;
    final globalAvg  = d['global_avg_duration_min'] as int?;
    final pd         = _periodData(d);

    return ListView(padding: const EdgeInsets.all(14), children: [
      // ── Sélecteur période ──
      _periodSelector(),
      const SizedBox(height: 14),

      // ── KPI période ──
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHeader(Icons.event_note, 'Tâches terminées — ${_periodLabel()}', const Color(0xFF26C6A6)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _bigStat('${pd['done'] ?? 0}', 'Terminées', const Color(0xFF26C6A6))),
          _vDivider(),
          Expanded(child: _bigStat('${pd['total'] ?? 0}', 'Total', AppTheme.skyLight)),
          _vDivider(),
          Expanded(child: _bigStat(_fmt(pd['avg_min'] as int?), 'Moy. durée', const Color(0xFFFFB347))),
        ]),
        const SizedBox(height: 12),
        _progressRow(
          (pd['total'] as int? ?? 0) > 0
              ? (pd['done'] as int? ?? 0) / (pd['total'] as int)
              : 0.0,
          const Color(0xFF26C6A6),
        ),
      ])),
      const SizedBox(height: 12),

      // ── Comparaison 3 périodes ──
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHeader(Icons.compare_arrows, 'Comparaison des périodes', AppTheme.skyLight),
        const SizedBox(height: 12),
        _periodCompareRow(d),
      ])),
      const SizedBox(height: 12),

      // ── KPI globaux ──
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHeader(Icons.summarize_outlined, 'Totaux globaux', AppTheme.c3),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4,
          children: [
            _kpi(Icons.people, '$totalTechs', 'Techniciens', AppTheme.skyLight),
            _kpi(Icons.assignment, '$totalAll', 'Total tâches', AppTheme.skyBottom),
            _kpi(Icons.check_circle_outline, '$doneAll', 'Terminées', const Color(0xFF26C6A6)),
            _kpi(Icons.pending_outlined, '$pendAll', 'En attente', const Color(0xFFFFB347)),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 13, color: AppTheme.c2),
          const SizedBox(width: 5),
          Text('Durée moyenne globale : ${_fmt(globalAvg)}',
              style: const TextStyle(color: AppTheme.c2, fontSize: 12)),
        ]),
      ])),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — Techniciens (tableau de bord personnel)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTechniciansTab() {
    final techs = (_data!['technicians'] as List?) ?? [];
    if (techs.isEmpty) {
      return Center(child: Text('Aucun technicien', style: TextStyle(color: AppTheme.c2.withOpacity(0.5))));
    }
    return ListView(padding: const EdgeInsets.all(14), children: [
      _periodSelector(),
      const SizedBox(height: 14),
      ...techs.map((t) => _techCard(t as Map)),
    ]);
  }

  Widget _techCard(Map tech) {
    final score     = (tech['score'] as num?)?.toDouble() ?? 0.0;
    final total     = tech['total_tasks']      as int? ?? 0;
    final completed = tech['completed_tasks']  as int? ?? 0;
    final avgMin    = tech['avg_duration_min'] as int?;
    final color     = _scoreColor(score);
    final pd        = (tech['periods']?[_period] as Map?) ?? {};
    final pdDone    = pd['done']    as int? ?? 0;
    final pdTotal   = pd['total']   as int? ?? 0;
    final pdAvg     = pd['avg_min'] as int?;
    final rate      = total > 0 ? completed / total : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TechnicianPersonalDashboardScreen(tech: tech),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardBlue(radius: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            _avatar(tech['username'] as String, color),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tech['username'] as String,
                  style: const TextStyle(color: AppTheme.c1, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Voir tableau de bord →',
                  style: TextStyle(color: AppTheme.skyLight.withOpacity(0.7), fontSize: 11)),
            ])),
            _scoreBadge(score, color),
          ]),
          const SizedBox(height: 12),

          // Période sélectionnée
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(children: [
              Expanded(child: _miniStat('$pdDone', 'Terminées\n${_periodLabel()}', color)),
              _vDivider(),
              Expanded(child: _miniStat('$pdTotal', 'Total\n${_periodLabel()}', AppTheme.skyLight)),
              _vDivider(),
              Expanded(child: _miniStat(_fmt(pdAvg), 'Moy. durée\n${_periodLabel()}', const Color(0xFFFFB347))),
            ]),
          ),
          const SizedBox(height: 10),

          // Barres
          _labeledBar('Complétion globale', '$completed/$total', rate, const Color(0xFF26C6A6)),
          const SizedBox(height: 6),
          _labeledBar('Score', '$score/5', score / 5, color),
          const SizedBox(height: 10),

          // Chips
          Wrap(spacing: 6, children: [
            _chip(Icons.timer_outlined, _fmt(avgMin), 'moy. globale', AppTheme.skyLight),
            _chip(Icons.task_alt, '$completed', 'terminées', const Color(0xFF26C6A6)),
            _chip(Icons.pending_outlined, '${total - completed}', 'en attente', const Color(0xFFFFB347)),
          ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — Classement
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRankingTab() {
    final techs = (_data!['technicians'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(14), children: [
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHeader(Icons.leaderboard, 'Classement par score', const Color(0xFFFFB347)),
        const SizedBox(height: 12),
        ...techs.asMap().entries.map((e) => _rankRow(e.key, e.value as Map)),
      ])),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secHeader(Icons.speed, 'Classement par rapidité', AppTheme.skyLight),
        const SizedBox(height: 12),
        ..._rankBySpeed(techs),
      ])),
    ]);
  }

  List<Widget> _rankBySpeed(List techs) {
    final sorted = [...techs]..sort((a, b) {
      final da = (a as Map)['avg_duration_min'] as int? ?? 9999;
      final db = (b as Map)['avg_duration_min'] as int? ?? 9999;
      return da.compareTo(db);
    });
    return sorted.asMap().entries.map((e) {
      final t   = e.value as Map;
      final avg = t['avg_duration_min'] as int?;
      final color = avg == null ? Colors.white24
          : avg <= 30 ? const Color(0xFF26C6A6)
          : avg <= 60 ? const Color(0xFFFFB347)
          : const Color(0xFFFF6B35);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(width: 24, child: Text('${e.key + 1}.', style: TextStyle(color: AppTheme.c2, fontSize: 12))),
          _avatar(t['username'] as String, color, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(t['username'] as String,
              style: const TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w600))),
          Text(_fmt(avg), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );
    }).toList();
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

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
          child: Text(e.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? Colors.white : AppTheme.c2,
              fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ));
    }).toList());
  }

  String _periodLabel() {
    switch (_period) {
      case 'day':   return 'Aujourd\'hui';
      case 'week':  return 'Cette semaine';
      case 'month': return 'Ce mois';
      default:      return 'Total';
    }
  }

  Widget _periodCompareRow(Map d) {
    final periods = d['periods'] as Map? ?? {};
    final rows = [
      ('Aujourd\'hui', 'day',   AppTheme.skyLight),
      ('Semaine',      'week',  const Color(0xFF26C6A6)),
      ('Mois',         'month', const Color(0xFFFFB347)),
    ];
    return Column(children: rows.map((r) {
      final pd    = (periods[r.$2] as Map?) ?? {};
      final done  = pd['done']  as int? ?? 0;
      final total = pd['total'] as int? ?? 0;
      final avg   = pd['avg_min'] as int?;
      final rate  = total > 0 ? done / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 80, child: Text(r.$1, style: TextStyle(color: r.$3, fontSize: 11, fontWeight: FontWeight.w600))),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate, minHeight: 8,
                backgroundColor: AppTheme.skyTop.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(r.$3),
              ),
            )),
            const SizedBox(width: 8),
            Text('$done', style: TextStyle(color: r.$3, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('/$total', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11)),
            const SizedBox(width: 8),
            Text(_fmt(avg), style: TextStyle(color: AppTheme.c2, fontSize: 10)),
          ]),
        ]),
      );
    }).toList());
  }

  Widget _rankRow(int index, Map tech) {
    final score = (tech['score'] as num?)?.toDouble() ?? 0.0;
    final color = _scoreColor(score);
    final medals = ['🥇', '🥈', '🥉'];
    final medal  = index < 3 ? medals[index] : '${index + 1}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 30, child: Text(medal, style: const TextStyle(fontSize: 16))),
        _avatar(tech['username'] as String, color, size: 30),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tech['username'] as String,
              style: const TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
            value: score / 5, minHeight: 5,
            backgroundColor: AppTheme.skyTop.withOpacity(0.25),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          )),
        ])),
        const SizedBox(width: 8),
        Text('$score/5', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppTheme.cardBlue(radius: 16),
    child: child,
  );

  Widget _secHeader(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 7),
    Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
  ]);

  Widget _kpi(IconData icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: AppTheme.cardBlue(radius: 12),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppTheme.c2, fontSize: 9)),
      ]),
    ]),
  );

  Widget _bigStat(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 10), textAlign: TextAlign.center),
  ]);

  Widget _miniStat(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 9), textAlign: TextAlign.center),
  ]);

  Widget _vDivider() => Container(width: 1, height: 36, color: AppTheme.skyTop.withOpacity(0.3));

  Widget _progressRow(double value, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: LinearProgressIndicator(
      value: value, minHeight: 10,
      backgroundColor: AppTheme.skyTop.withOpacity(0.25),
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );

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

  Widget _avatar(String username, Color color, {double size = 34}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(size / 3)),
    child: Center(child: Text(username.substring(0, 1).toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.44))),
  );

  Widget _scoreBadge(double score, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: 11, color: color),
      const SizedBox(width: 3),
      Text('$score/5', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _chip(IconData icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 9)),
    ]),
  );
}
