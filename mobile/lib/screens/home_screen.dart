import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../utils/app_theme.dart';
import '../widgets/ai_alerts_widget.dart';
import 'login_screen.dart';
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
  List<Task> _tasks = [];
  bool _isLoading = false;
  String _currentPage = 'TODO';
  String? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _taskService.getTasks();
      _sortTasks(tasks);
      if (mounted) setState(() { _tasks = tasks; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortTasks(List<Task> tasks) {
    tasks.sort((a, b) {
      final pa = _statusPriority(a.status);
      final pb = _statusPriority(b.status);
      if (pa != pb) return pa.compareTo(pb);
      return b.startTime.compareTo(a.startTime);
    });
  }

  // Mise à jour locale immédiate — déplace la tâche en bas sans recharger l'API
  void _markTaskDoneLocally(String taskId) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx < 0) return;
      final old = _tasks[idx];
      _tasks[idx] = Task(
        id: old.id, reference: old.reference, name: old.name,
        description: old.description, partnerName: old.partnerName,
        startTime: old.startTime, endTime: old.endTime,
        status: TaskStatus.completed,
      );
      _sortTasks(_tasks);
      _expandedTaskId = null;
    });
  }

  int _statusPriority(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:       return 0; // New — en premier
      case TaskStatus.inProgress: return 1; // Planifié — au milieu
      case TaskStatus.completed:  return 2; // Done — à la fin
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo: return AppTheme.c3;
      case TaskStatus.inProgress: return AppTheme.c2;
      case TaskStatus.completed: return const Color(0xFF4CAF50);
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
                          _buildSidebarItem('TO DO', 'TODO', AppTheme.skyLight, isDark),
                          _buildDivider(isDark),
                          _buildSidebarItem('MON BORD', 'DASHBOARD', const Color(0xFF26C6A6), isDark),
                          _buildDivider(isDark),
                          _buildSidebarItem('ASSETS', 'ASSETS', AppTheme.accentAlt, isDark),
                          _buildDivider(isDark),
                          _buildSidebarItem('DIAGNOSTIQUE', 'DIAGNOSTIQUE', AppTheme.accent, isDark),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Deconnexion',
                                  style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold)),
                              content: const Text('Voulez-vous vraiment vous deconnecter ?',
                                  style: TextStyle(color: AppTheme.c2)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _authService.logout();
                                    if (!mounted) return;
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppTheme.topbar(isDark),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh, color: AppTheme.c1, size: 22),
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
                                      ? const DiagnosticScreen()
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

  Widget _buildSidebarItem(String title, String page, Color color, bool isDark) {
    final isSelected = _currentPage == page;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentPage = page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.sidebarSelected(isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.15))
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
      return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                  Text('Aucune tâche disponible', style: TextStyle(color: AppTheme.c2.withOpacity(0.5))),
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
        const AiAlertsWidget(),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: AppTheme.cardBlue(radius: 24),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _TaskCard(
                  task: task,
                  statusColor: _getStatusColor(task.status),
                  isExpanded: _expandedTaskId == task.id,
                  onToggleExpand: () {
                    setState(() {
                      _expandedTaskId = _expandedTaskId == task.id ? null : task.id;
                    });
                  },
                  onRefresh: _loadTasks,
                  onMarkDone: () => _markTaskDoneLocally(task.id),
                );
              },
            ),
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
  final VoidCallback onMarkDone;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRefresh,
    required this.onMarkDone,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  final _taskService = TaskService();

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
            style: TextButton.styleFrom(foregroundColor: AppTheme.c2.withOpacity(0.7)),
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
      // Mise à jour locale immédiate — déplace en bas instantanément
      widget.onMarkDone();
      try {
        await _taskService.updateStage(widget.task.id, 'termine');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche terminée ✓'), backgroundColor: Color(0xFF26C6A6)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur mise à jour'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    final statusIcon = widget.task.status == TaskStatus.completed
        ? Icons.check_circle_rounded
        : widget.task.status == TaskStatus.inProgress
            ? Icons.timelapse_rounded
            : Icons.fiber_new_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardBlue(radius: 16),
      child: Opacity(
        opacity: widget.task.status == TaskStatus.completed ? 0.65 : 1.0,
        child: Column(
          children: [
            GestureDetector(
              onTap: widget.onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: widget.statusColor, size: 20),
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
                            style: TextStyle(color: AppTheme.c1, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.task.partnerName.isNotEmpty ? widget.task.partnerName : widget.task.startTime,
                            style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: widget.statusColor.withOpacity(0.4)),
                      ),
                      child: Text(widget.task.status.label,
                          style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.c2.withOpacity(0.5), size: 20),
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
                    bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoRow(Icons.tag, 'Réf', widget.task.reference),
                    const SizedBox(height: 5),
                    _infoRow(Icons.description_outlined, 'Description', widget.task.description),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => TaskDetailScreen(task: widget.task)),
                              );
                              if (!mounted) return;
                              widget.onRefresh();
                            },
                            icon: const Icon(Icons.attach_file, size: 15),
                            label: const Text('Détails', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.skyLight,
                    side: const BorderSide(color: AppTheme.skyTop),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                          ),
                        ),
                        if (widget.task.status != TaskStatus.completed) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _markAsCompleted,
                              icon: const Icon(Icons.check_rounded, size: 15),
                              label: const Text('Terminer', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.btnTerminer,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 9),
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
        Text('$label: ', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
      ],
    );
  }
}



