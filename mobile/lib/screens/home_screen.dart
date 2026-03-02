import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'assets_screen.dart';
import 'diagnostic_screen.dart';
import 'task_detail_screen.dart';

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
  bool _isDarkMode = false;
  String? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final apiTasks = await _taskService.getTasks();
      final mergedTasks = [...apiTasks];
      if (mergedTasks.length < 6) {
        for (final fallbackTask in _fallbackTasks) {
          if (mergedTasks.length == 6) {
            break;
          }
          if (mergedTasks.any((task) => task.id == fallbackTask.id)) {
            continue;
          }
          mergedTasks.add(fallbackTask);
        }
      }

      mergedTasks.sort(_compareTasksByPriority);
      _tasks = mergedTasks.take(6).toList();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      final fallbackTasks = [..._fallbackTasks]..sort(_compareTasksByPriority);
      _tasks = fallbackTasks;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _statusPriority(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 0;
      case TaskStatus.inProgress:
        return 1;
      case TaskStatus.completed:
        return 2;
    }
  }

  int _compareTasksByPriority(Task a, Task b) {
    final statusComparison = _statusPriority(a.status).compareTo(_statusPriority(b.status));
    if (statusComparison != 0) {
      return statusComparison;
    }

    final startA = _tryParseHour(a.startTime);
    final startB = _tryParseHour(b.startTime);
    return startA.compareTo(startB);
  }

  int _tryParseHour(String value) {
    final match = RegExp(r'^(\d{1,2})').firstMatch(value.trim());
    if (match == null) {
      return 99;
    }
    return int.tryParse(match.group(1) ?? '') ?? 99;
  }

  List<Task> get _fallbackTasks => [
        Task(
          id: 'local-001',
          reference: 'REF-001',
          name: 'Tache 1',
          description: 'Diagnostic technique',
          partnerName: 'Partenaire Alpha',
          startTime: '08h',
          endTime: '09h',
          status: TaskStatus.todo,
        ),
        Task(
          id: 'local-002',
          reference: 'REF-002',
          name: 'Tache 2',
          description: 'Verification cablage GPS',
          partnerName: 'Partenaire Beta',
          startTime: '09h',
          endTime: '10h',
          status: TaskStatus.todo,
        ),
        Task(
          id: 'local-003',
          reference: 'REF-003',
          name: 'Tache 3',
          description: 'Mise a jour firmware',
          partnerName: 'Partenaire Gamma',
          startTime: '10h',
          endTime: '11h',
          status: TaskStatus.todo,
        ),
        Task(
          id: 'local-004',
          reference: 'REF-004',
          name: 'Tache 4',
          description: 'Configuration dispositif',
          partnerName: 'Partenaire Delta',
          startTime: '11h',
          endTime: '12h',
          status: TaskStatus.inProgress,
        ),
        Task(
          id: 'local-005',
          reference: 'REF-005',
          name: 'Tache 5',
          description: 'Test connectivite reseau',
          partnerName: 'Partenaire Epsilon',
          startTime: '13h',
          endTime: '14h',
          status: TaskStatus.completed,
        ),
        Task(
          id: 'local-006',
          reference: 'REF-006',
          name: 'Tache 6',
          description: 'Validation finale',
          partnerName: 'Partenaire Zeta',
          startTime: '15h',
          endTime: '16h',
          status: TaskStatus.completed,
        ),
      ];

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return const Color(0xFFF7A6B0);
      case TaskStatus.inProgress:
        return const Color(0xFFF6DD72);
      case TaskStatus.completed:
        return const Color(0xFF95E08C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.black : null,
          image: _isDarkMode
              ? null
              : const DecorationImage(
                  image: AssetImage('assets/fond tunav.jpg'),
                  fit: BoxFit.cover,
                ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                width: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border(
                    right: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildSidebarItem('TO DO', 'TODO', Colors.white),
                    const SizedBox(height: 20),
                    _buildSidebarItem('ASSETS', 'ASSETS', const Color(0xFF5DADE2)),
                    const SizedBox(height: 20),
                    _buildSidebarItem('DIAGNOSTIQUE', 'DIAGNOSTIQUE', const Color(0xFF48C9B0)),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF5B7C99),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text(
                                'Deconnexion',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              content: const Text(
                                'Voulez-vous vraiment vous deconnecter ?',
                                style: TextStyle(color: Colors.white70),
                              ),
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
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                            onPressed: _loadTasks,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Switch(
                              value: _isDarkMode,
                              onChanged: (v) => setState(() => _isDarkMode = v),
                              activeColor: Colors.black,
                              activeTrackColor: Colors.grey.shade800,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _currentPage == 'TODO'
                          ? _buildTodoPage()
                          : _currentPage == 'ASSETS'
                              ? const AssetsScreen()
                              : _currentPage == 'DIAGNOSTIQUE'
                                  ? const DiagnosticScreen()
                                  : _buildPlaceholderPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String title, String page, Color color) {
    final isSelected = _currentPage == page;
    return GestureDetector(
      onTap: () => setState(() => _currentPage = page),
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCE1E8).withOpacity(0.78) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF3D4C5A) : color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final frameDecoration = _isDarkMode
        ? BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.3),
          )
        : BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xA14A8DB0),
                Color(0xC329A8B3),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.42), width: 1.3),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(4),
      decoration: frameDecoration,
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : null,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage() {
    return Center(
      child: Text(
        'Page $_currentPage',
        style: const TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final Task task;
  final Color statusColor;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRefresh;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onRefresh,
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
        backgroundColor: const Color(0xFF5B7C99),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Marquer cette tache comme terminee ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF90EE90),
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.updateTaskStatus(widget.task.id, TaskStatus.completed);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tache terminee'), backgroundColor: Colors.green),
        );
        widget.onRefresh();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de terminer cette tache pour le moment'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xC473B2CC),
            Color(0xB560AEC8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.34), width: 1),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onToggleExpand,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.task.startTime} -> ${widget.task.endTime}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.task.status.label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoRow('Reference', widget.task.reference),
                  const SizedBox(height: 8),
                  _buildInfoRow('Description', widget.task.description),
                  const SizedBox(height: 8),
                  _buildInfoRow('Partenaire', widget.task.partnerName),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: widget.task)),
                      );
                      if (!mounted) return;
                      widget.onRefresh();
                    },
                    icon: const Icon(Icons.file_copy_outlined, size: 16),
                    label: const Text('Fichiers', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C9EE6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                  if (widget.task.status != TaskStatus.completed) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _markAsCompleted,
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Terminer', style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7DDB82),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xDDEDF5F7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

