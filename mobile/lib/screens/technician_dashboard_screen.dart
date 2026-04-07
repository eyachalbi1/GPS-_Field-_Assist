import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() => _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  final _taskService  = TaskService();
  final _authService  = AuthService();
  List<Task> _tasks   = [];
  String? _username;
  bool _loading       = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _authService.getUsername(),
      _taskService.getTasks(),
    ]);
    if (mounted) {
      setState(() {
        _username = results[0] as String?;
        _tasks    = results[1] as List<Task>;
        _loading  = false;
      });
    }
  }

  // ── Calculs ────────────────────────────────────────────────────────────────
  int get _total     => _tasks.length;
  int get _done      => _tasks.where((t) => t.status == TaskStatus.completed).length;
  int get _inProg    => _tasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get _todo      => _tasks.where((t) => t.status == TaskStatus.todo).length;
  double get _rate   => _total > 0 ? _done / _total : 0.0;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  Color _rateColor() =>
      _rate >= 0.75 ? const Color(0xFF26C6A6)
      : _rate >= 0.4 ? const Color(0xFFFFB347)
      : const Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTopbar.withOpacity(0.9),
        title: const Row(children: [
          Icon(Icons.person_outline, color: AppTheme.skyLight, size: 20),
          SizedBox(width: 8),
          Text('Mon tableau de bord',
              style: TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.c1),
            onPressed: _load,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.skyLight))
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildWelcome(),
                  const SizedBox(height: 14),
                  _buildProgressCard(),
                  const SizedBox(height: 12),
                  _buildStatsGrid(),
                  const SizedBox(height: 12),
                  _buildStatusBars(),
                  const SizedBox(height: 12),
                  _buildRecentTasks(),
                ],
              ),
      ),
    );
  }

  // ── Carte de bienvenue ─────────────────────────────────────────────────────
  Widget _buildWelcome() {
    final name = _username ?? 'Technicien';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.skyMid.withOpacity(0.8), AppTheme.skyBottom.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.skyLight.withOpacity(0.4)),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_greeting()},', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _done == _total && _total > 0
                ? '🎉 Toutes vos tâches sont terminées !'
                : '$_todo tâche${_todo > 1 ? 's' : ''} en attente',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
          ),
        ])),
        // Mini score circulaire
        _circleRate(),
      ]),
    );
  }

  Widget _circleRate() {
    final color = _rateColor();
    return Stack(alignment: Alignment.center, children: [
      SizedBox(
        width: 52, height: 52,
        child: CircularProgressIndicator(
          value: _rate,
          strokeWidth: 4,
          backgroundColor: Colors.white.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      Text('${(_rate * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }

  // ── Barre de progression globale ───────────────────────────────────────────
  Widget _buildProgressCard() {
    final color = _rateColor();
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHeader(Icons.trending_up, 'Progression globale', color),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _rate, minHeight: 14,
            backgroundColor: AppTheme.skyTop.withOpacity(0.25),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        )),
        const SizedBox(width: 10),
        Text('$_done / $_total',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Text(
        _rate == 0 ? 'Aucune tâche terminée pour le moment'
            : _rate < 0.5 ? 'Continuez, vous êtes sur la bonne voie !'
            : _rate < 1.0 ? 'Excellent travail, presque terminé !'
            : '🎉 Toutes les tâches sont terminées !',
        style: TextStyle(color: AppTheme.c2.withOpacity(0.8), fontSize: 12),
      ),
    ]));
  }

  // ── Grille KPI ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: [
        _kpiTile(Icons.fiber_new_rounded,      '$_todo',   'Nouvelles',  AppTheme.skyLight),
        _kpiTile(Icons.timelapse_rounded,      '$_inProg', 'En cours',   const Color(0xFFFFB347)),
        _kpiTile(Icons.check_circle_rounded,   '$_done',   'Terminées',  const Color(0xFF26C6A6)),
      ],
    );
  }

  Widget _kpiTile(IconData icon, String value, String label, Color color) {
    return Container(
      decoration: AppTheme.cardBlue(radius: 14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppTheme.c2, fontSize: 10)),
      ]),
    );
  }

  // ── Barres par statut ──────────────────────────────────────────────────────
  Widget _buildStatusBars() {
    if (_total == 0) return const SizedBox.shrink();
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHeader(Icons.bar_chart, 'Répartition des tâches', AppTheme.skyLight),
      const SizedBox(height: 12),
      _statusBar('Nouvelles',  _todo,   _total, AppTheme.skyLight),
      const SizedBox(height: 8),
      _statusBar('En cours',   _inProg, _total, const Color(0xFFFFB347)),
      const SizedBox(height: 8),
      _statusBar('Terminées',  _done,   _total, const Color(0xFF26C6A6)),
    ]));
  }

  Widget _statusBar(String label, int count, int total, Color color) {
    final val = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.c2, fontSize: 11))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val, minHeight: 8,
            backgroundColor: AppTheme.skyTop.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        )),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        Text('/$total', style: TextStyle(color: AppTheme.c2.withOpacity(0.4), fontSize: 11)),
      ]),
    ]);
  }

  // ── Tâches récentes ────────────────────────────────────────────────────────
  Widget _buildRecentTasks() {
    final recent = _tasks.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHeader(Icons.access_time, 'Tâches récentes', AppTheme.c3),
      const SizedBox(height: 10),
      ...recent.map((t) {
        final color = t.status == TaskStatus.completed ? const Color(0xFF26C6A6)
            : t.status == TaskStatus.inProgress ? const Color(0xFFFFB347)
            : AppTheme.skyLight;
        final icon = t.status == TaskStatus.completed ? Icons.check_circle_rounded
            : t.status == TaskStatus.inProgress ? Icons.timelapse_rounded
            : Icons.fiber_new_rounded;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(t.name,
                style: const TextStyle(color: AppTheme.c1, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(t.status.label,
                  style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }),
    ]));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppTheme.cardBlue(radius: 16),
    child: child,
  );

  Widget _secHeader(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  ]);
}
