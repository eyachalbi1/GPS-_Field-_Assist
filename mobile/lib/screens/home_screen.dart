import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'login_screen.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/gps_alert_notifier.dart';
import '../widgets/ai_alerts_widget.dart';
import '../services/gps_device_service.dart';
import '../services/gps_prediction_service.dart';
import 'assets_screen.dart';
import 'diagnostic_screen.dart';
import 'task_detail_screen.dart';
import 'technician_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _taskService = TaskService();
  final _diagKey = GlobalKey<DiagnosticScreenState>();
  List<Task> _tasks = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String _currentPage = 'TODO';
  String? _expandedTaskId;
  bool _alertBlink = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    gpsAlertNotifier.addListener(_onAlertChanged);
    // Charger les prédictions GPS dès l'ouverture pour afficher l'icône alerte
    GpsDeviceService.fetchDevices().then((devices) {
      if (!mounted) return;
      final preds = GpsPredictionService.predict(devices);
      gpsAlertNotifier.value = GpsPredictionService.alertCount(preds);
    }).catchError((_) {});
  }

  void _onAlertChanged() {
    final hasAlert = gpsAlertNotifier.value > 0;
    if (hasAlert && _blinkTimer == null) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted) setState(() => _alertBlink = !_alertBlink);
      });
    } else if (!hasAlert) {
      _blinkTimer?.cancel();
      _blinkTimer = null;
      if (mounted) setState(() => _alertBlink = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchWorkloadPrediction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final r = await http.get(
          Uri.parse('${Config.baseUrl}/api/tasks/workload-prediction'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200)
        return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  void _showWorkloadPrediction() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WorkloadPredictionSheet(fetch: _fetchWorkloadPrediction),
    );
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _taskService.getTasks();
      _sortTasks(tasks);
      // Detect if result came from cache (both APIs failed silently)
      bool offline = false;
      try {
        await Future.any([
          http
              .get(Uri.parse('http://41.226.24.13:5000/api/helpdesk/tasks'))
              .timeout(const Duration(seconds: 4)),
        ]);
      } catch (_) {
        offline = true;
      }
      if (mounted)
        setState(() {
          _tasks = tasks;
          _isLoading = false;
          _isOffline = offline;
        });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    gpsAlertNotifier.removeListener(_onAlertChanged);
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _sortTasks(List<Task> tasks) {
    tasks.sort((a, b) {
      final pa = _statusPriority(a.status);
      final pb = _statusPriority(b.status);
      if (pa != pb) return pa.compareTo(pb);
      return b.startTime.compareTo(a.startTime);
    });
  }

  void _updateTaskLocally(String taskId, TaskStatus newStatus) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx < 0) return;
      final old = _tasks[idx];
      _tasks[idx] = Task(
        id: old.id,
        reference: old.reference,
        name: old.name,
        description: old.description,
        partnerName: old.partnerName,
        startTime: old.startTime,
        endTime: old.endTime,
        status: newStatus,
      );
      _sortTasks(_tasks);
      _expandedTaskId = null;
    });
  }

  int _statusPriority(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 0;
      case TaskStatus.inProgress:
        return 1;
      case TaskStatus.completed:
        return 2;
      case TaskStatus.cancelled:
        return 3;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return AppTheme.c3;
      case TaskStatus.inProgress:
        return AppTheme.c2;
      case TaskStatus.completed:
        return const Color(0xFF26C6A6);
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── Sidebar ──
            Container(
              width: 62,
              color: AppTheme.sidebar(isDark),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSidebarItem(
                            'TO DO', 'TODO', AppTheme.skyLight, isDark),
                        _buildDivider(isDark),
                        _buildSidebarItem('MON BORD', 'DASHBOARD',
                            const Color(0xFF26C6A6), isDark),
                        _buildDivider(isDark),
                        _buildSidebarItem(
                            'ASSETS', 'ASSETS', AppTheme.accentAlt, isDark),
                        _buildDivider(isDark),
                        _buildSidebarItem('DIAGNOSTIQUE', 'DIAGNOSTIQUE',
                            AppTheme.accent, isDark),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: IconButton(
                      icon: Icon(Icons.logout, color: AppTheme.c2, size: 24),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.card(isDark),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Deconnexion',
                                style: TextStyle(
                                    color: AppTheme.c1,
                                    fontWeight: FontWeight.bold)),
                            content: const Text(
                                'Voulez-vous vraiment vous deconnecter ?',
                                style: TextStyle(color: AppTheme.c2)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _authService.logout();
                                  if (!mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) => LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.btnDark,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Deconnexion'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: AppTheme.topbar(isDark),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // ── Icône prédiction charge (visible uniquement sur TODO) ──
                        if (_currentPage == 'TODO')
                          IconButton(
                            icon: const Icon(Icons.auto_graph_rounded,
                                color: Color(0xFF26C6A6), size: 22),
                            tooltip: 'Prédiction de charge',
                            onPressed: _showWorkloadPrediction,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF26C6A6).withOpacity(0.12),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        const Spacer(),
                        // ── Icône alerte GPS ──
                        ValueListenableBuilder<int>(
                          valueListenable: gpsAlertNotifier,
                          builder: (_, count, __) {
                            if (count == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.notifications_active_rounded,
                                      color: _alertBlink
                                          ? const Color(0xFFFF4444)
                                          : const Color(0xFFFF4444)
                                              .withOpacity(0.35),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(
                                          () => _currentPage = 'DIAGNOSTIQUE');
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        _diagKey.currentState?.showAlertPanel();
                                      });
                                    },
                                    tooltip: '$count module(s) en alerte',
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF4444)
                                          .withOpacity(0.12),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('$count',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.refresh, color: AppTheme.c1, size: 22),
                          onPressed: _loadTasks,
                          tooltip: 'Actualiser',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _currentPage == 'TODO'
                        ? _buildTodoPage(isDark)
                        : _currentPage == 'DASHBOARD'
                            ? const TechnicianDashboardScreen()
                            : _currentPage == 'ASSETS'
                                ? const AssetsScreen()
                                : _currentPage == 'DIAGNOSTIQUE'
                                    ? DiagnosticScreen(key: _diagKey)
                                    : const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.sidebarDivider(isDark),
    );
  }

  Widget _buildSidebarItem(
      String title, String page, Color color, bool isDark) {
    final isSelected = _currentPage == page;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentPage = page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.sidebarSelected(isDark)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark
                      ? Colors.white.withOpacity(0.25)
                      : Colors.black.withOpacity(0.15))
                  : AppTheme.sidebarDivider(isDark),
              width: 1.2,
            ),
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoPage(bool isDark) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_tasks.isEmpty) {
      return Column(
        children: [
          const AiAlertsWidget(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt, size: 56, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text('Aucune tâche disponible',
                      style: TextStyle(color: AppTheme.c2.withOpacity(0.5))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadTasks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            color: Colors.orange.withOpacity(0.85),
            child: const Row(children: [
              Icon(Icons.wifi_off, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text('Hors ligne — données du dernier chargement',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ),
        const AiAlertsWidget(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return _TaskCard(
                task: task,
                statusColor: _getStatusColor(task.status),
                isExpanded: _expandedTaskId == task.id,
                onToggleExpand: () {
                  setState(() {
                    _expandedTaskId =
                        _expandedTaskId == task.id ? null : task.id;
                  });
                },
                onRefresh: _loadTasks,
                onUpdateLocal: (s) => _updateTaskLocally(task.id, s),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatefulWidget {
  final Task task;
  final Color statusColor;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRefresh;
  final void Function(TaskStatus) onUpdateLocal;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRefresh,
    required this.onUpdateLocal,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  final _taskService = TaskService();

  Future<void> _markAsInProgress() async {
    widget.onUpdateLocal(TaskStatus.inProgress); // optimistic
    final ok = await _taskService.updateStage(widget.task.id, 'en_cours');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Tâche en cours ✓' : 'Erreur mise à jour'),
      backgroundColor: ok ? const Color(0xFFFFB347) : Colors.redAccent,
    ));
  }

  Future<void> _markAsCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card(false),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer',
            style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold)),
        content: const Text('Marquer cette tâche comme terminée ?',
            style: TextStyle(color: AppTheme.c2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.c2.withOpacity(0.7)),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.btnDark),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onUpdateLocal(TaskStatus.completed); // optimistic
      final ok = await _taskService.updateStage(widget.task.id, 'termine');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Tâche terminée ✓' : 'Erreur mise à jour'),
        backgroundColor: ok ? const Color(0xFF26C6A6) : Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    final statusIcon = widget.task.status == TaskStatus.completed
        ? Icons.check_circle_rounded
        : widget.task.status == TaskStatus.inProgress
            ? Icons.timelapse_rounded
            : widget.task.status == TaskStatus.cancelled
                ? Icons.cancel_outlined
                : Icons.fiber_new_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardBlue(radius: 0).color,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: widget.statusColor.withOpacity(0.75), width: 1.8),
      ),
      child: Opacity(
        opacity: (widget.task.status == TaskStatus.completed ||
                widget.task.status == TaskStatus.cancelled)
            ? 0.65
            : 1.0,
        child: Column(
          children: [
            GestureDetector(
              onTap: widget.onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(statusIcon, color: widget.statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.c1,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.task.partnerName.isNotEmpty
                                ? widget.task.partnerName
                                : widget.task.startTime,
                            style: TextStyle(
                                color: AppTheme.c2.withOpacity(0.5),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: widget.statusColor.withOpacity(0.4)),
                      ),
                      child: Text(widget.task.status.label,
                          style: TextStyle(
                              color: widget.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                        widget.isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppTheme.c2.withOpacity(0.5),
                        size: 20),
                  ],
                ),
              ),
            ),
            if (widget.isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoRow(Icons.tag, 'Réf', widget.task.reference),
                    const SizedBox(height: 5),
                    _infoRow(Icons.description_outlined, 'Description',
                        widget.task.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TaskDetailScreen(task: widget.task)),
                              );
                              if (!mounted) return;
                              widget.onRefresh();
                            },
                            icon: const Icon(Icons.attach_file, size: 15),
                            label: const Text('Détails',
                                style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.skyLight,
                              side: const BorderSide(color: AppTheme.skyTop),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                        if (widget.task.status != TaskStatus.completed &&
                            widget.task.status != TaskStatus.cancelled) ...[
                          const SizedBox(width: 8),
                          if (widget.task.status == TaskStatus.todo)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _markAsInProgress,
                                icon: const Icon(Icons.timelapse_rounded,
                                    size: 15),
                                label: const Text('En cours',
                                    style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB347),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                          if (widget.task.status == TaskStatus.inProgress)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _markAsCompleted,
                                icon: const Icon(Icons.check_rounded, size: 15),
                                label: const Text('Terminer',
                                    style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.btnTerminer,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: AppTheme.c2.withOpacity(0.5)),
        const SizedBox(width: 5),
        Text('$label: ',
            style:
                TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }
}

// ── BottomSheet : Prédiction de charge IA ─────────────────────────────────────────────
class _WorkloadPredictionSheet extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() fetch;
  const _WorkloadPredictionSheet({required this.fetch});

  @override
  State<_WorkloadPredictionSheet> createState() =>
      _WorkloadPredictionSheetState();
}

class _WorkloadPredictionSheetState extends State<_WorkloadPredictionSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.fetch().then((d) {
      if (mounted)
        setState(() {
          _data = d;
          _loading = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF26C6A6).withOpacity(0.3)),
      ),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF26C6A6))))
          : _data == null
              ? const SizedBox(
                  height: 120,
                  child: Center(
                      child: Text('Données indisponibles',
                          style: TextStyle(color: AppTheme.c2))))
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final username = d['username'] as String? ?? '';
    final current = d['current_week'] as int? ?? 0;
    final predicted = d['predicted_next'] as int? ?? 0;
    final pending = d['pending_tasks'] as int? ?? 0;
    final completed = d['completed_total'] as int? ?? 0;
    final trend = d['trend'] as String? ?? 'stable';
    final trendPct = d['trend_pct'] as int? ?? 0;
    final history = (d['weekly_history'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];

    final trendColor = trend == 'hausse'
        ? const Color(0xFFFF6B35)
        : trend == 'baisse'
            ? const Color(0xFF26C6A6)
            : const Color(0xFFFFB347);
    final trendIcon = trend == 'hausse'
        ? Icons.trending_up
        : trend == 'baisse'
            ? Icons.trending_down
            : Icons.trending_flat;
    final maxVal = [...history, predicted].fold(1, (a, b) => a > b ? a : b);

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
              child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: AppTheme.c2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          )),

          // Titre
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF26C6A6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Color(0xFF26C6A6), size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Prédiction de charge IA',
                  style: TextStyle(
                      color: AppTheme.c1,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              if (username.isNotEmpty)
                Text(username,
                    style: TextStyle(
                        color: AppTheme.c2.withOpacity(0.6), fontSize: 11)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: trendColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trendIcon, size: 13, color: trendColor),
                const SizedBox(width: 4),
                Text(
                  trendPct == 0
                      ? 'Stable'
                      : '${trendPct > 0 ? '+' : ''}$trendPct%',
                  style: TextStyle(
                      color: trendColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),

          // Barres : charge actuelle vs prévue
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.skyTop.withOpacity(0.25)),
            ),
            child: Column(children: [
              _predBar('Cette semaine', current, maxVal, AppTheme.skyLight),
              const SizedBox(height: 10),
              _predBar('Semaine prochaine (prévue)', predicted, maxVal,
                  const Color(0xFF26C6A6),
                  isDashed: true),
            ]),
          ),
          const SizedBox(height: 14),

          // Historique mini-barres (8 semaines)
          if (history.isNotEmpty) ...[
            Text('Historique 8 semaines',
                style: TextStyle(
                    color: AppTheme.c2.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ...history.asMap().entries.map((e) {
                    final isLast = e.key == history.length - 1;
                    final h = maxVal == 0 ? 0.0 : e.value / maxVal;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 4 + (36 * h),
                                decoration: BoxDecoration(
                                  color: isLast
                                      ? AppTheme.skyLight
                                      : AppTheme.skyTop.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ]),
                      ),
                    );
                  }),
                  // Barre prédiction
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 +
                                  (36 *
                                      (maxVal == 0 ? 0.0 : predicted / maxVal)),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26C6A6).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: const Color(0xFF26C6A6), width: 1),
                              ),
                            ),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                      child: Text('S-8',
                          style: TextStyle(
                              color: AppTheme.c2.withOpacity(0.4),
                              fontSize: 8))),
                  Text('S+1 ▲',
                      style: TextStyle(
                          color: const Color(0xFF26C6A6).withOpacity(0.8),
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Chips résumé
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(Icons.pending_outlined, '$pending', 'en attente',
                const Color(0xFFFFB347)),
            _chip(Icons.check_circle_outline, '$completed', 'terminées',
                const Color(0xFF26C6A6)),
            _chip(Icons.auto_graph_rounded, '$predicted', 'prévues S+1',
                const Color(0xFF26C6A6)),
          ]),
        ]);
  }

  Widget _predBar(String label, int value, int max, Color color,
      {bool isDashed = false}) {
    final pct = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: isDashed ? color : AppTheme.c2,
                    fontSize: 11,
                    fontWeight:
                        isDashed ? FontWeight.w700 : FontWeight.normal))),
        Text('$value tâche${value > 1 ? 's' : ''}',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: isDashed ? 10 : 8,
          backgroundColor: AppTheme.skyTop.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(
              isDashed ? color : color.withOpacity(0.6)),
        ),
      ),
    ]);
  }

  Widget _chip(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
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
