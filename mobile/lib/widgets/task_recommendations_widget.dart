import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_diagnostic_service.dart';
import '../services/youtube_service.dart';
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
  // Map tutorialTitle → liste de vidéos YouTube
  final Map<String, List<Map<String, String>>> _videos = {};
  final Set<String> _loadingVideos = {};
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

    // Pré-charger les vidéos pour chaque tutoriel
    if (result != null) {
      final tutorials = (result['tutorials'] as List?) ?? [];
      final taskType  = result['task_type'] as String? ?? '';
      for (final t in tutorials) {
        final title = (t as Map)['title'] as String? ?? '';
        if (title.isNotEmpty) _fetchVideos(title, taskType);
      }
    }
  }

  Future<void> _fetchVideos(String tutorialTitle, String taskType) async {
    if (_videos.containsKey(tutorialTitle)) return;
    if (mounted) setState(() => _loadingVideos.add(tutorialTitle));

    final query  = YoutubeService.buildQuery(tutorialTitle, taskType);
    final videos = await YoutubeService.search(query, maxResults: 3);

    if (mounted) {
      setState(() {
        _videos[tutorialTitle] = videos;
        _loadingVideos.remove(tutorialTitle);
      });
    }
  }

  Future<void> _openVideo(String url) async {
    if (url.isEmpty) return;

    // Extraire le videoId depuis l'URL
    final uri = Uri.parse(url);
    final videoId = uri.queryParameters['v'] ?? uri.pathSegments.lastOrNull ?? '';

    // Construire l'URL courte youtu.be — reconnue par l'app YouTube
    final targetUrl = videoId.isNotEmpty
        ? 'https://youtu.be/$videoId'
        : url;

    final target = Uri.parse(targetUrl);
    try {
      final launched = await launchUrl(target, mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(target, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(target, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.skyLight));
    }
    if (_data == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, size: 40, color: Colors.white24),
        const SizedBox(height: 10),
        Text('Recommandations indisponibles', style: TextStyle(color: AppTheme.c2.withOpacity(0.5))),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () { setState(() => _loading = true); _load(); },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Réessayer'),
        ),
      ]));
    }

    final tools     = (_data!['tools']     as List?) ?? [];
    final parts     = (_data!['parts']     as List?) ?? [];
    final tutorials = (_data!['tutorials'] as List?) ?? [];
    final duration  = _data!['duration']   as Map?;
    final taskType  = _data!['task_type']  as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── Type + durée ──
        Row(children: [
          _typeBadge(taskType),
          const Spacer(),
          if (duration != null) _durationBadge(duration),
        ]),
        const SizedBox(height: 14),

        // ── Outils ──
        if (tools.isNotEmpty) ...[
          _sectionTitle(Icons.build_outlined, 'Outils nécessaires', AppTheme.skyLight),
          const SizedBox(height: 8),
          _chipWrap(tools.cast<String>(), AppTheme.skyLight),
          const SizedBox(height: 14),
        ],

        // ── Pièces ──
        if (parts.isNotEmpty) ...[
          _sectionTitle(Icons.inventory_2_outlined, 'Pièces à prévoir', const Color(0xFFFFB347)),
          const SizedBox(height: 8),
          _chipWrap(parts.cast<String>(), const Color(0xFFFFB347)),
          const SizedBox(height: 14),
        ],

        // ── Tutoriels vidéo YouTube ──
        if (tutorials.isNotEmpty) ...[
          _sectionTitle(Icons.smart_display_outlined, 'Tutoriels vidéo', const Color(0xFFFF0000)),
          const SizedBox(height: 10),
          ...tutorials.map((t) => _tutorialSection(t as Map, taskType)),
        ],
      ],
    );
  }

  // ── Section tutoriel avec vidéos YouTube ────────────────────────────────────
  Widget _tutorialSection(Map tutorial, String taskType) {
    final title   = tutorial['title'] as String? ?? '';
    final module  = tutorial['module'] as String? ?? '';
    final videos  = _videos[title] ?? [];
    final loading = _loadingVideos.contains(title);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête tutoriel
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.play_circle_filled, color: Color(0xFFFF0000), size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w700)),
            if (module.isNotEmpty && module != 'général')
              Text('Module : $module', style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 8),

        // Vidéos
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF0000))),
              const SizedBox(width: 10),
              Text('Recherche de vidéos…', style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 11)),
            ]),
          )
        else if (videos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Aucune vidéo trouvée', style: TextStyle(color: AppTheme.c2.withOpacity(0.4), fontSize: 11)),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              itemBuilder: (_, i) => _videoCard(videos[i]),
            ),
          ),

        Container(height: 1, color: AppTheme.skyTop.withOpacity(0.25), margin: const EdgeInsets.only(top: 8)),
      ]),
    );
  }

  // ── Carte vidéo YouTube ──────────────────────────────────────────────────────
  Widget _videoCard(Map<String, String> video) {
    final thumb   = video['thumbnail'] ?? '';
    final title   = video['title']    ?? '';
    final channel = video['channelTitle'] ?? '';
    final url     = video['url']      ?? '';

    return GestureDetector(
      onTap: () => _openVideo(url),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 10),
        decoration: AppTheme.cardBlue(radius: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: 180, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            // Bouton play overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.black.withOpacity(0.25),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                ),
              ),
            ),
            // Badge YouTube
            Positioned(
              top: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('YT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(color: AppTheme.c1, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text(channel,
                    style: TextStyle(color: AppTheme.c2.withOpacity(0.6), fontSize: 9),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
    width: 180, height: 80,
    color: AppTheme.darkSurface,
    child: const Center(child: Icon(Icons.play_circle_outline, color: AppTheme.c2, size: 32)),
  );

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _typeBadge(String type) {
    const labels = {
      'installation':  ('Installation',  Icons.build),
      'maintenance':   ('Maintenance',   Icons.settings),
      'diagnostic':    ('Diagnostic',    Icons.search),
      'configuration': ('Configuration', Icons.tune),
      'remplacement':  ('Remplacement',  Icons.swap_horiz),
      'default':       ('Intervention',  Icons.work_outline),
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
    final h = min ~/ 60; final m = min % 60;
    final label = h > 0 ? '${h}h${m > 0 ? '${m}min' : ''}' : '${m}min';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF26C6A6).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26C6A6).withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(source == 'historique' ? Icons.history : Icons.timer_outlined, size: 13, color: const Color(0xFF26C6A6)),
        const SizedBox(width: 5),
        Text('~$label', style: const TextStyle(color: Color(0xFF26C6A6), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text(source == 'historique' ? '(historique)' : '(estimé)',
            style: TextStyle(color: const Color(0xFF26C6A6).withOpacity(0.6), fontSize: 9)),
      ]),
    );
  }

  Widget _sectionTitle(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
  ]);

  Widget _chipWrap(List<String> items, Color color) => Wrap(
    spacing: 7, runSpacing: 7,
    children: items.map((item) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(item, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    )).toList(),
  );
}
