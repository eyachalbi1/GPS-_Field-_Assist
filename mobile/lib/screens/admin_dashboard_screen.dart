import 'dart:async';
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
  List<Map<String, dynamic>> _feed = [];
  Map<String, dynamic> _aiInsights = {};
  bool _aiLoading = false;
  Timer? _feedTimer;

  // Période sélectionnée : 'day' | 'week' | 'month' | 'all'
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
    _loadFeed();
    _loadAiInsights();
    _feedTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadFeed();
      _loadAiInsights();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _feedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AdminService.getDashboard();
      if (mounted)
        setState(() {
          _data = d;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _loadFeed() async {
    final feed = await AdminService.getActivityFeed();
    if (mounted) setState(() => _feed = feed);
  }

  Future<void> _loadAiInsights() async {
    if (mounted) setState(() => _aiLoading = true);
    final data = await AdminService.getLiveInsights();
    if (mounted)
      setState(() {
        _aiInsights = data;
        _aiLoading = false;
      });
  }

  String _fmt(int? min) {
    if (min == null) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    return h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
  }

  Color _scoreColor(double s) => s >= 4
      ? const Color(0xFF26C6A6)
      : s >= 2.5
          ? const Color(0xFFFFB347)
          : const Color(0xFFFF4444);

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
          Text('Dashboard',
              style: TextStyle(
                  color: AppTheme.c1,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.c1),
              onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF26C6A6),
          labelColor: const Color(0xFF26C6A6),
          unselectedLabelColor: AppTheme.c2,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Vue globale'),
            Tab(
                icon: Icon(Icons.people_outline, size: 18),
                text: 'Techniciens'),
            Tab(icon: Icon(Icons.leaderboard, size: 18), text: 'Classement'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF26C6A6)))
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
  Widget _buildError() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
    final d = _data!;
    final totalTechs = d['total_technicians'] as int? ?? 0;
    final totalAll = d['total_tasks'] as int? ?? 0;
    final doneAll = d['completed_tasks'] as int? ?? 0;
    final pendAll = d['pending_tasks'] as int? ?? 0;
    final globalAvg = d['global_avg_duration_min'] as int?;
    final pd = _periodData(d);

    return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _periodSelector(),
          const SizedBox(height: 14),

          // ── KPI période ──
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _secHeader(
                    Icons.event_note,
                    'Tâches terminées — ${_periodLabel()}',
                    const Color(0xFF26C6A6)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _bigStat('${pd['done'] ?? 0}', 'Terminées',
                          const Color(0xFF26C6A6))),
                  _vDivider(),
                  Expanded(
                      child: _bigStat(
                          '${pd['total'] ?? 0}', 'Total', AppTheme.skyLight)),
                  _vDivider(),
                  Expanded(
                      child: _bigStat(_fmt(pd['avg_min'] as int?), 'Moy. durée',
                          const Color(0xFFFFB347))),
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
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _secHeader(Icons.compare_arrows, 'Comparaison des périodes',
                    AppTheme.skyLight),
                const SizedBox(height: 12),
                _periodCompareRow(d),
              ])),
          const SizedBox(height: 12),

          // ── KPI globaux ──
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _secHeader(
                    Icons.summarize_outlined, 'Totaux globaux', AppTheme.c3),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    _kpi(Icons.people, '$totalTechs', 'Techniciens',
                        AppTheme.skyLight),
                    _kpi(Icons.assignment, '$totalAll', 'Total tâches',
                        AppTheme.skyBottom),
                    _kpi(Icons.check_circle_outline, '$doneAll', 'Terminées',
                        const Color(0xFF26C6A6)),
                    _kpi(Icons.pending_outlined, '$pendAll', 'En attente',
                        const Color(0xFFFFB347)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.timer_outlined,
                      size: 13, color: AppTheme.c2),
                  const SizedBox(width: 5),
                  Text('Durée moyenne globale : ${_fmt(globalAvg)}',
                      style: const TextStyle(color: AppTheme.c2, fontSize: 12)),
                ]),
              ])),
          const SizedBox(height: 12),

          // ── AI Live Insights + Timeline activité ──
          _buildActivityFeed(),
        ]);
  }

  Widget _aiSummaryBar(Map summary) => const SizedBox.shrink();

  Widget _aiHealthScore(Map summary) {
    final rate = summary['week_completion_rate'] as int? ?? 0;
    final anomalyCount = summary['total_anomalies'] as int? ?? 0;
    final insightCount = summary['total_insights'] as int? ?? 0;
    final healthScore = (100 - anomalyCount * 15 + insightCount * 5).clamp(0, 100);
    final healthColor = healthScore >= 80
        ? const Color(0xFF26C6A6)
        : healthScore >= 50
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF4444);
    final healthLabel = healthScore >= 80 ? 'Excellent' : healthScore >= 50 ? 'Moyen' : 'Critique';
    final rateColor = rate >= 80
        ? const Color(0xFF26C6A6)
        : rate >= 50
            ? const Color(0xFFFFB347)
            : const Color(0xFFFF4444);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.2)),
      ),
      child: Row(children: [
        SizedBox(
          width: 52, height: 52,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: healthScore / 100,
              strokeWidth: 5,
              backgroundColor: AppTheme.skyTop.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
            Text('$healthScore', style: TextStyle(color: healthColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Score santé', style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 10)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: healthColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(healthLabel, style: TextStyle(color: healthColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Complétion semaine', style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 9)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 5,
                  backgroundColor: AppTheme.skyTop.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                ),
              ),
            ])),
            const SizedBox(width: 8),
            Text('$rate%', style: TextStyle(color: rateColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(children: [
          _aiMiniCounter('$anomalyCount', 'anomalie${anomalyCount != 1 ? 's' : ''}',
              anomalyCount > 0 ? const Color(0xFFFF4444) : const Color(0xFF26C6A6)),
          const SizedBox(height: 6),
          _aiMiniCounter('$insightCount', 'insight${insightCount != 1 ? 's' : ''}',
              const Color(0xFF26C6A6)),
        ]),
      ]),
    );
  }

  Widget _aiMiniCounter(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 8)),
    ]),
  );

  Widget _aiCategoryHeader(IconData icon, String label, Color color, int count) =>
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Container(
          margin: const EdgeInsets.only(left: 8),
          height: 1,
          color: color.withOpacity(0.2),
        )),
      ]);

  Widget _aiInsightItem(Map<String, dynamic> item, {bool isLast = false}) {
    final colorHex = item['color'] as String? ?? '#7C4DFF';
    final color = _hexColor(colorHex);
    final severity = item['severity'] as String? ?? 'info';
    final title = item['title'] as String? ?? '';
    final message = item['message'] as String? ?? '';
    final iconName = item['icon'] as String? ?? 'info';
    final icon = _aiIcon(iconName);
    final severityColor = severity == 'high'
        ? const Color(0xFFFF4444)
        : severity == 'medium'
            ? const Color(0xFFFFB347)
            : color;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: severityColor.withOpacity(0.35)),
          ),
          child: Icon(icon, size: 14, color: severityColor),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: severityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            if (severity == 'high')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('ALERTE',
                    style: TextStyle(
                        color: Color(0xFFFF4444),
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 3),
          Text(message,
              style: TextStyle(
                  color: AppTheme.c2.withOpacity(0.8),
                  fontSize: 11,
                  height: 1.4)),
        ])),
      ]),
    );
  }

  IconData _aiIcon(String name) {
    switch (name) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'star':
        return Icons.star_rounded;
      case 'person_off':
        return Icons.person_off_outlined;
      case 'build':
        return Icons.build_outlined;
      case 'device_unknown':
        return Icons.device_unknown_outlined;
      case 'trending_down':
        return Icons.trending_down_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      default:
        return Icons.psychology_outlined;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Timeline activité temps réel
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActivityFeed() {
    final anomalies = List<Map<String, dynamic>>.from(_aiInsights['anomalies'] ?? []);
    final insights = List<Map<String, dynamic>>.from(_aiInsights['insights'] ?? []);
    final recs = List<Map<String, dynamic>>.from(_aiInsights['recommendations'] ?? []);
    final summary = (_aiInsights['summary'] as Map?) ?? {};

    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // En-tête
      Row(children: [
        _secHeader(Icons.bolt, 'Activité récente', const Color(0xFF26C6A6)),
        const Spacer(),
        if (_aiLoading)
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF26C6A6)))
        else
          GestureDetector(
            onTap: _loadAiInsights,
            child: const Icon(Icons.refresh, size: 14, color: Color(0xFF26C6A6)),
          ),
        const SizedBox(width: 8),
        _LiveDot(),
        const SizedBox(width: 5),
        const Text('Live', style: TextStyle(color: Color(0xFF26C6A6), fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),

      // Score santé IA
      if (summary.isNotEmpty) ...[
        _aiHealthScore(summary),
        const SizedBox(height: 14),
      ],

      // Anomalies
      if (anomalies.isNotEmpty) ...[
        _aiCategoryHeader(Icons.warning_amber_rounded, 'Anomalies', const Color(0xFFFF4444), anomalies.length),
        const SizedBox(height: 6),
        ...anomalies.asMap().entries.map((e) =>
            _aiInsightItem(e.value, isLast: e.key == anomalies.length - 1)),
        const SizedBox(height: 12),
      ],

      // Insights positifs
      if (insights.isNotEmpty) ...[
        _aiCategoryHeader(Icons.trending_up_rounded, 'Points positifs', const Color(0xFF26C6A6), insights.length),
        const SizedBox(height: 6),
        ...insights.asMap().entries.map((e) =>
            _aiInsightItem(e.value, isLast: e.key == insights.length - 1)),
        const SizedBox(height: 12),
      ],

      // Recommandations
      if (recs.isNotEmpty) ...[
        _aiCategoryHeader(Icons.lightbulb_outline, 'Recommandations', const Color(0xFFFFB347), recs.length),
        const SizedBox(height: 6),
        ...recs.asMap().entries.map((e) =>
            _aiInsightItem(e.value, isLast: e.key == recs.length - 1 && _feed.isEmpty)),
        if (_feed.isNotEmpty) const SizedBox(height: 12),
      ],

      // État nominal si rien
      if (!_aiLoading && anomalies.isEmpty && insights.isEmpty && recs.isEmpty && _feed.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(child: Column(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF26C6A6), size: 28),
            const SizedBox(height: 6),
            Text('Système nominal — aucune anomalie',
                style: TextStyle(color: const Color(0xFF26C6A6).withOpacity(0.8), fontSize: 12)),
          ])),
        ),

      // Feed activité
      if (_feed.isNotEmpty) ...[
        _aiCategoryHeader(Icons.history, 'Dernières actions', AppTheme.skyLight, _feed.length.clamp(0, 8)),
        const SizedBox(height: 8),
        ...(_feed.take(8).toList().asMap().entries.map((e) =>
            _feedItem(e.value, isLast: e.key == (_feed.length - 1).clamp(0, 7)))),
      ],
    ]));
  }

  Widget _feedItem(Map<String, dynamic> event, {bool isLast = false}) {
    final colorHex = event['color'] as String? ?? '#5DA5B3';
    final color = _hexColor(colorHex);
    final icon = _feedIcon(event['icon'] as String? ?? 'info');
    final msg = event['message'] as String? ?? '';
    final ts = event['ts'] as String? ?? '';
    final ago = _timeAgo(ts);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          if (!isLast)
            Container(width: 1.5, height: 28, color: color.withOpacity(0.15)),
        ]),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg,
              style: const TextStyle(
                  color: AppTheme.c1, fontSize: 12, height: 1.4)),
          const SizedBox(height: 3),
          Text(ago,
              style:
                  TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 10)),
        ])),
      ]),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.skyLight;
    }
  }

  IconData _feedIcon(String name) {
    switch (name) {
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'assignment':
        return Icons.assignment_outlined;
      case 'star':
        return Icons.star_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _timeAgo(String isoTs) {
    try {
      final dt = DateTime.parse(isoTs);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — Techniciens (tableau de bord personnel)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTechniciansTab() {
    final techs = (_data!['technicians'] as List?) ?? [];
    if (techs.isEmpty) {
      return Center(
          child: Text('Aucun technicien',
              style: TextStyle(color: AppTheme.c2.withOpacity(0.5))));
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _periodSelector(),
          const SizedBox(height: 14),
          ...techs.map((t) => _techCard(t as Map)),
        ]);
  }

  Widget _techCard(Map tech) {
    final score = (tech['score'] as num?)?.toDouble() ?? 0.0;
    final total = tech['total_tasks'] as int? ?? 0;
    final completed = tech['completed_tasks'] as int? ?? 0;
    final avgMin = tech['avg_duration_min'] as int?;
    final color = _scoreColor(score);
    final pd = (tech['periods']?[_period] as Map?) ?? {};
    final pdDone = pd['done'] as int? ?? 0;
    final pdTotal = pd['total'] as int? ?? 0;
    final pdAvg = pd['avg_min'] as int?;
    final rate = total > 0 ? completed / total : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
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
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tech['username'] as String,
                      style: const TextStyle(
                          color: AppTheme.c1,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('Voir tableau de bord →',
                      style: TextStyle(
                          color: AppTheme.skyLight.withOpacity(0.7),
                          fontSize: 11)),
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
              Expanded(
                  child: _miniStat(
                      '$pdDone', 'Terminées\n${_periodLabel()}', color)),
              _vDivider(),
              Expanded(
                  child: _miniStat('$pdTotal', 'Total\n${_periodLabel()}',
                      AppTheme.skyLight)),
              _vDivider(),
              Expanded(
                  child: _miniStat(_fmt(pdAvg), 'Moy. durée\n${_periodLabel()}',
                      const Color(0xFFFFB347))),
            ]),
          ),
          const SizedBox(height: 10),

          // Barres
          _labeledBar('Complétion globale', '$completed/$total', rate,
              const Color(0xFF26C6A6)),
          const SizedBox(height: 6),
          _labeledBar('Score', '$score/5', score / 5, color),
          const SizedBox(height: 10),

          // Chips
          Wrap(spacing: 6, children: [
            _chip(Icons.timer_outlined, _fmt(avgMin), 'moy. globale',
                AppTheme.skyLight),
            _chip(Icons.task_alt, '$completed', 'terminées',
                const Color(0xFF26C6A6)),
            _chip(Icons.pending_outlined, '${total - completed}', 'en attente',
                const Color(0xFFFFB347)),
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
    return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _secHeader(Icons.leaderboard, 'Classement par score',
                    const Color(0xFFFFB347)),
                const SizedBox(height: 12),
                ...techs
                    .asMap()
                    .entries
                    .map((e) => _rankRow(e.key, e.value as Map)),
              ])),
          const SizedBox(height: 12),
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _secHeader(
                    Icons.speed, 'Classement par rapidité', AppTheme.skyLight),
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
      final t = e.value as Map;
      final avg = t['avg_duration_min'] as int?;
      final color = avg == null
          ? Colors.white24
          : avg <= 30
              ? const Color(0xFF26C6A6)
              : avg <= 60
                  ? const Color(0xFFFFB347)
                  : const Color(0xFFFF6B35);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 24,
              child: Text('${e.key + 1}.',
                  style: TextStyle(color: AppTheme.c2, fontSize: 12))),
          _avatar(t['username'] as String, color, size: 28),
          const SizedBox(width: 8),
          Expanded(
              child: Text(t['username'] as String,
                  style: const TextStyle(
                      color: AppTheme.c1,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          Text(_fmt(avg),
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );
    }).toList();
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

  Widget _periodSelector() {
    const periods = {
      'day': 'Jour',
      'week': 'Semaine',
      'month': 'Mois',
      'all': 'Tout'
    };
    return Row(
        children: periods.entries.map((e) {
      final sel = _period == e.key;
      return Expanded(
          child: GestureDetector(
        onTap: () => setState(() => _period = e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFF26C6A6)
                : AppTheme.darkCard.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel
                    ? const Color(0xFF26C6A6)
                    : AppTheme.skyTop.withOpacity(0.3)),
          ),
          child: Text(
            e.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? Colors.white : AppTheme.c2,
              fontSize: 12,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ));
    }).toList());
  }

  String _periodLabel() {
    switch (_period) {
      case 'day':
        return 'Aujourd\'hui';
      case 'week':
        return 'Cette semaine';
      case 'month':
        return 'Ce mois';
      default:
        return 'Total';
    }
  }

  Widget _periodCompareRow(Map d) {
    final periods = d['periods'] as Map? ?? {};
    final rows = [
      ('Aujourd\'hui', 'day', AppTheme.skyLight),
      ('Semaine', 'week', const Color(0xFF26C6A6)),
      ('Mois', 'month', const Color(0xFFFFB347)),
    ];
    return Column(
        children: rows.map((r) {
      final pd = (periods[r.$2] as Map?) ?? {};
      final done = pd['done'] as int? ?? 0;
      final total = pd['total'] as int? ?? 0;
      final avg = pd['avg_min'] as int?;
      final rate = total > 0 ? done / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
                width: 80,
                child: Text(r.$1,
                    style: TextStyle(
                        color: r.$3,
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
            Expanded(
                child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                backgroundColor: AppTheme.skyTop.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(r.$3),
              ),
            )),
            const SizedBox(width: 8),
            Text('$done',
                style: TextStyle(
                    color: r.$3, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('/$total',
                style: TextStyle(
                    color: AppTheme.c2.withOpacity(0.5), fontSize: 11)),
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
    final medal = index < 3 ? medals[index] : '${index + 1}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text(medal, style: const TextStyle(fontSize: 16))),
        _avatar(tech['username'] as String, color, size: 30),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tech['username'] as String,
              style: const TextStyle(
                  color: AppTheme.c1,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: score / 5,
                minHeight: 5,
                backgroundColor: AppTheme.skyTop.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              )),
        ])),
        const SizedBox(width: 8),
        Text('$score/5',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700))),
      ]);

  Widget _kpi(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: AppTheme.cardBlue(radius: 12),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: const TextStyle(color: AppTheme.c2, fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      );

  Widget _bigStat(String value, String label, Color color) => Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 10),
            textAlign: TextAlign.center),
      ]);

  Widget _miniStat(String value, String label, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 9),
            textAlign: TextAlign.center),
      ]);

  Widget _vDivider() =>
      Container(width: 1, height: 36, color: AppTheme.skyTop.withOpacity(0.3));

  Widget _progressRow(double value, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: AppTheme.skyTop.withOpacity(0.25),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );

  Widget _labeledBar(String label, String right, double value, Color color) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(color: AppTheme.c2, fontSize: 10)),
            const Spacer(),
            Text(right,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppTheme.skyTop.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              )),
        ],
      );

  Widget _avatar(String username, Color color, {double size = 34}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(size / 3)),
        child: Center(
            child: Text(username.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.44))),
      );

  Widget _scoreBadge(double score, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text('$score/5',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _chip(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.6), fontSize: 9)),
        ]),
      );
}

// ── Point clignotant "Live" ───────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({this.color = const Color(0xFF26C6A6)});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> {
  bool _on = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _on ? 1.0 : 0.15,
        duration: const Duration(milliseconds: 400),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      );
}
