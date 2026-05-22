import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'login_screen.dart';
import 'technician_tasks_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _technicians = [];
  bool _loading = true;
  String? _error;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminService.getTechnicians();
      if (mounted) setState(() { _technicians = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _showAddDialog() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.person_add, color: AppTheme.skyBottom, size: 22),
            const SizedBox(width: 8),
            Text('Nouveau technicien', style: TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: TextStyle(color: AppTheme.c1),
                decoration: InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.c2),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                style: TextStyle(color: AppTheme.c1),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.c2),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.c2),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: AppTheme.c2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.skyBottom),
              onPressed: () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
                try {
                  await AdminService.createTechnician(userCtrl.text.trim(), passCtrl.text);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Technicien "${userCtrl.text}" créé ✓'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> tech) async {
    final ctrl = TextEditingController(text: tech['username']);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.edit, color: AppTheme.skyBottom, size: 22),
          const SizedBox(width: 8),
          Text('Modifier username', style: TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: AppTheme.c1),
          decoration: InputDecoration(
            labelText: 'Nouveau username',
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.c2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppTheme.c2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.skyBottom),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await AdminService.updateUsername(tech['id'], ctrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username mis à jour ✓'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> tech) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Text('Supprimer', style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold)),
        ]),
        content: Text('Supprimer le technicien "${tech['username']}" ?',
            style: TextStyle(color: AppTheme.c2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.c2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminService.deleteTechnician(tech['id']);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technicien supprimé'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Column(
            children: [
              // TopBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: AppTheme.darkTopbar.withOpacity(0.7),
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.skyBottom, size: 26),
                    const SizedBox(width: 10),
                    Text('Administration', style: TextStyle(color: AppTheme.c1, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.dashboard_outlined, color: Color(0xFF26C6A6)),
                      tooltip: 'Dashboard',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppTheme.c1),
                      onPressed: _load,
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: AppTheme.c2),
                      onPressed: () async {
                        await _authService.logout();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Stats
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatCard(
                      icon: Icons.people,
                      label: 'Techniciens',
                      value: '${_technicians.length}',
                      color: AppTheme.skyBottom,
                    ),
                  ],
                ),
              ),
              // Header liste
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Liste des techniciens',
                        style: TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBottom,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Liste
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppTheme.skyBottom))
                    : _error != null
                        ? Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyle(color: AppTheme.c2)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                            ],
                          ))
                        : _technicians.isEmpty
                            ? Center(child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 56, color: AppTheme.c2.withOpacity(0.4)),
                                  const SizedBox(height: 12),
                                  Text('Aucun technicien', style: TextStyle(color: AppTheme.c2)),
                                ],
                              ))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _technicians.length,
                                itemBuilder: (_, i) => _TechCard(
                                  tech: _technicians[i],
                                  onEdit: () => _showEditDialog(_technicians[i]),
                                  onDelete: () => _confirmDelete(_technicians[i]),
                                  onRefresh: _load,
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: AppTheme.cardBlue(radius: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: AppTheme.c1, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: AppTheme.c2, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechCard extends StatefulWidget {
  final Map<String, dynamic> tech;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;
  const _TechCard({required this.tech, required this.onEdit, required this.onDelete, required this.onRefresh});

  @override
  State<_TechCard> createState() => _TechCardState();
}

class _TechCardState extends State<_TechCard> {
  late final TextEditingController _odooCtrl;
  bool _savingId = false;
  bool _showPerf = false;
  Map<String, dynamic>? _perf;
  bool _loadingPerf = false;

  @override
  void initState() {
    super.initState();
    _odooCtrl = TextEditingController(
      text: widget.tech['assigned_to_id']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _odooCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePerf() async {
    if (_showPerf) { setState(() => _showPerf = false); return; }
    setState(() { _showPerf = true; _loadingPerf = _perf == null; });
    if (_perf == null) {
      try {
        final data = await AdminService.getTechnicianPerformance(widget.tech['id'] as int);
        if (mounted) setState(() { _perf = data; _loadingPerf = false; });
      } catch (_) {
        if (mounted) setState(() => _loadingPerf = false);
      }
    }
  }

  Future<void> _saveOdooId() async {
    setState(() => _savingId = true);
    try {
      await AdminService.updateOdooId(widget.tech['id'] as int, _odooCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID mis à jour ✓'), backgroundColor: Colors.green),
      );
      widget.onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _savingId = false);
    }
  }

  Widget _buildPerfPanel() {
    if (_loadingPerf) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF26C6A6), strokeWidth: 2)),
      );
    }
    if (_perf == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Données indisponibles', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 12)),
      );
    }

    final score     = (_perf!['score'] as num?)?.toDouble() ?? 0.0;
    final total     = _perf!['total_tasks']      as int? ?? 0;
    final completed = _perf!['completed_tasks']  as int? ?? 0;
    final avgMin    = _perf!['avg_duration_min'] as int?;
    final tasks     = (_perf!['tasks'] as List?) ?? [];

    final scoreColor = score >= 4 ? const Color(0xFF26C6A6)
        : score >= 2.5 ? const Color(0xFFFFB347)
        : const Color(0xFFFF4444);

    String fmtDur(int? min) {
      if (min == null) return '—';
      final h = min ~/ 60; final m = min % 60;
      return h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
    }

    final maxDur = tasks
        .map((x) => (x['duration_min'] as int?) ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.skyTop.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score global
          Row(children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB347)),
            const SizedBox(width: 5),
            Text('Évaluation globale', style: TextStyle(color: AppTheme.c2, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$score / 5', style: TextStyle(color: scoreColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 8,
              backgroundColor: AppTheme.skyTop.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 12),
          // Stats résumé
          Row(children: [
            _statChip(Icons.task_alt, '$completed/$total', 'tâches', const Color(0xFF26C6A6)),
            const SizedBox(width: 8),
            _statChip(Icons.timer_outlined, fmtDur(avgMin), 'moy.', AppTheme.skyLight),
          ]),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.list_alt, size: 12, color: AppTheme.c2),
              const SizedBox(width: 5),
              Text('Durée par tâche', style: TextStyle(color: AppTheme.c2, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ...tasks.take(5).map((t) {
              final dur    = t['duration_min'] as int?;
              final status = t['status'] as String? ?? '';
              final isDone = ['termine', 'done', 'completed'].contains(status);
              final barColor = dur == null ? Colors.white24
                  : dur <= 30 ? const Color(0xFF26C6A6)
                  : dur <= 60 ? const Color(0xFFFFB347)
                  : const Color(0xFFFF6B35);
              final barVal = (dur != null && maxDur > 0)
                  ? (dur / maxDur).clamp(0.0, 1.0)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          t['name'] as String? ?? t['reference'] as String? ?? '',
                          style: const TextStyle(color: AppTheme.c1, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(fmtDur(dur), style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isDone ? const Color(0xFF26C6A6) : AppTheme.c3).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDone ? 'TERMINÉ' : status.toUpperCase(),
                          style: TextStyle(
                            color: isDone ? const Color(0xFF26C6A6) : AppTheme.c3,
                            fontSize: 8, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barVal,
                        minHeight: 5,
                        backgroundColor: AppTheme.skyTop.withOpacity(0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (tasks.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${tasks.length - 5} autres tâches',
                    style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 10)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.tech['date_de_creation'] as String?)?.split('T').first ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TechnicianTasksScreen(technician: widget.tech)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardBlue(radius: 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.skyBottom.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (widget.tech['username'] as String).substring(0, 1).toUpperCase(),
                      style: TextStyle(color: AppTheme.skyBottom, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(widget.tech['username'] as String,
                            style: TextStyle(color: AppTheme.c1, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.c2.withOpacity(0.5)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.badge_outlined, size: 12, color: AppTheme.c2),
                        const SizedBox(width: 4),
                        Text(
                          widget.tech['assigned_to_id'] != null
                              ? 'Odoo ID: ${widget.tech['assigned_to_id']}'
                              : 'Odoo ID: non défini',
                          style: TextStyle(color: AppTheme.c2, fontSize: 11),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.c2),
                        const SizedBox(width: 4),
                        Text(date, style: TextStyle(color: AppTheme.c2, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: AppTheme.skyBottom, size: 20),
                  onPressed: widget.onEdit,
                  tooltip: 'Modifier username',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: widget.onDelete,
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Champ User ID
            Row(
              children: [
                Icon(Icons.fingerprint, size: 16, color: AppTheme.c2),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _odooCtrl,
                    style: TextStyle(color: AppTheme.c1, fontSize: 13),
                    onTap: () {},
                    decoration: InputDecoration(
                      labelText: 'User ID (Odoo)',
                      labelStyle: TextStyle(color: AppTheme.c2, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: AppTheme.darkSurface.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.c2.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.c2.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.skyBottom, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _savingId ? null : _saveOdooId,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBottom,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _savingId
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('OK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bouton performance
            GestureDetector(
              onTap: _togglePerf,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6A6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF26C6A6).withOpacity(0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.bar_chart, size: 15, color: Color(0xFF26C6A6)),
                  const SizedBox(width: 7),
                  const Text('Performance & durées', style: TextStyle(color: Color(0xFF26C6A6), fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(_showPerf ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFF26C6A6)),
                ]),
              ),
            ),
            // Panneau performance
            if (_showPerf) _buildPerfPanel(),
          ],
        ),
      ),
    );
  }
}


