import 'package:flutter/material.dart';
import '../services/ai_diagnostic_service.dart';
import '../utils/app_theme.dart';

class AiAlertsWidget extends StatefulWidget {
  const AiAlertsWidget({super.key});

  @override
  State<AiAlertsWidget> createState() => _AiAlertsWidgetState();
}

class _AiAlertsWidgetState extends State<AiAlertsWidget> {
  Map<String, dynamic>? _predictive;
  Map<String, dynamic>? _recommendations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      AiDiagnosticService.getPredictiveAlerts(),
      AiDiagnosticService.getRecommendations(),
    ]);
    if (mounted) {
      setState(() {
        _predictive = results[0];
        _recommendations = results[1];
        _loading = false;
      });
    }
  }

  // ── Compteurs ──────────────────────────────────────────────────────────────
  int get _criticalCount {
    final alerts = (_predictive?['alerts'] as List?) ?? [];
    return alerts.where((a) => a['severity'] == 'high').length;
  }

  int get _predictiveCount {
    final alerts = (_predictive?['alerts'] as List?)?.length ?? 0;
    final risks  = (_predictive?['at_risk'] as List?)?.length ?? 0;
    return alerts + risks;
  }

  int get _recoCount =>
      (_recommendations?['recurring_issues'] as List?)?.length ?? 0;

  bool get _hasAny => _criticalCount + _predictiveCount + _recoCount > 0;

  // ── Bottom sheet détaillé ──────────────────────────────────────────────────
  void _showDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, ctrl) => _DetailPanel(
          predictive: _predictive,
          recommendations: _recommendations,
          scrollController: ctrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pendant le chargement : rien (silencieux)
    if (_loading || !_hasAny) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showDetails,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.skyTop.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFF6B35), size: 15),
            const SizedBox(width: 8),
            const Text(
              'IA · Diagnostic & Maintenance',
              style: TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_criticalCount > 0) ...[
              _Badge(label: '$_criticalCount critique${_criticalCount > 1 ? 's' : ''}',
                  color: const Color(0xFFFF4444)),
              const SizedBox(width: 5),
            ],
            if (_predictiveCount > 0) ...[
              _Badge(label: '$_predictiveCount alerte${_predictiveCount > 1 ? 's' : ''}',
                  color: const Color(0xFFFF6B35)),
              const SizedBox(width: 5),
            ],
            if (_recoCount > 0)
              _Badge(label: '$_recoCount reco', color: AppTheme.skyLight),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.c2, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Badge coloré ──────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Panneau détaillé (bottom sheet) ───────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final Map<String, dynamic>? predictive;
  final Map<String, dynamic>? recommendations;
  final ScrollController scrollController;

  const _DetailPanel({
    required this.predictive,
    required this.recommendations,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final alerts  = (predictive?['alerts']  as List?) ?? [];
    final atRisk  = (predictive?['at_risk'] as List?) ?? [];
    final issues  = (recommendations?['recurring_issues'] as List?) ?? [];

    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppTheme.c2.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFF6B35), size: 16),
            const SizedBox(width: 8),
            const Text('Diagnostic IA & Maintenance prédictive',
                style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        Container(height: 1, color: AppTheme.skyTop.withOpacity(0.35)),
        // Contenu scrollable
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              // ── Alertes critiques ──
              if (alerts.isNotEmpty) ...[
                _sectionTitle(Icons.warning_amber_rounded, 'MAINTENANCE PRÉDICTIVE', const Color(0xFFFFB347)),
                ...alerts.map((a) => _alertCard(
                  color: a['severity'] == 'high' ? const Color(0xFFFF4444) : const Color(0xFFFFB347),
                  title: a['equipment'] ?? '',
                  body: a['message'] ?? '',
                  tag: a['severity'] == 'high' ? 'CRITIQUE' : 'ALERTE',
                )),
                const SizedBox(height: 10),
              ],
              // ── Tendances ──
              if (atRisk.isNotEmpty) ...[
                _sectionTitle(Icons.trending_up, 'TENDANCES CROISSANTES', const Color(0xFFFF6B35)),
                ...atRisk.map((r) => _alertCard(
                  color: r['risk'] == 'élevé' ? const Color(0xFFFF4444) : const Color(0xFFFFB347),
                  title: r['equipment'] ?? '',
                  body: '+${r['trend_pct']}% d\'interventions — risque ${r['risk']}',
                  tag: '${r['interventions_recent']} / 30j',
                )),
                const SizedBox(height: 10),
              ],
              // ── Recommandations SMS ──
              if (issues.isNotEmpty) ...[
                _sectionTitle(Icons.sms, 'RECOMMANDATIONS DIAGNOSTIC', AppTheme.skyLight),
                ...issues.map((issue) {
                  final symptom = issue['symptom'] as String? ?? '';
                  final cmds = SMS_HINTS[symptom] ?? [];
                  return _alertCard(
                    color: AppTheme.c3,
                    title: '"$symptom" — ${issue['count']}x',
                    body: cmds.isNotEmpty ? 'SMS suggérés : ${cmds.take(2).join(', ')}' : 'Voir diagnostic SMS',
                    tag: '${cmds.length} cmd',
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _alertCard({required Color color, required String title, required String body, required String tag}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(body, style: TextStyle(color: AppTheme.c2.withOpacity(0.75), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

const SMS_HINTS = {
  'pas de signal':   ['STATUS', 'GPSON'],
  'pas de position': ['GPSON', 'RESET'],
  'hors ligne':      ['STATUS', 'APN'],
  'batterie':        ['STATUS'],
  'installation':    ['BEGIN,<pwd>', 'APN,<apn>'],
};
