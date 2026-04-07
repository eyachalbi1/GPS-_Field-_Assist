import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import '../widgets/task_recommendations_widget.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  final _taskService = TaskService();
  final _picker = ImagePicker();
  late final TabController _tabController;

  final List<XFile> _selectedImages = [];
  final List<XFile> _selectedVideos = [];
  final List<String> _uploadedUrls = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadExistingMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingMedia() async {
    try {
      final urls = await _taskService.getTaskMedia(widget.task.id);
      if (!mounted) return;
      setState(() => _uploadedUrls.addAll(urls));
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) setState(() => _selectedImages.addAll(files));
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _selectedVideos.add(file));
  }

  Future<void> _pickVideoCamera() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (file != null) setState(() => _selectedVideos.add(file));
  }

  Future<void> _uploadAll() async {
    final all = [..._selectedImages, ..._selectedVideos];
    if (all.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final urls = await _taskService.uploadFiles(widget.task.id, all);
      if (!mounted) return;
      setState(() {
        _uploadedUrls.addAll(urls);
        _selectedImages.clear();
        _selectedVideos.clear();
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichiers envoyés ✓'), backgroundColor: Color(0xFF26C6A6)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAsCompleted() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(false),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmer', style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.bold)),
        content: const Text('Marquer cette tâche comme terminée ?', style: TextStyle(color: AppTheme.c2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: AppTheme.c2.withOpacity(0.7)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _taskService.updateStage(widget.task.id, 'termine');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tâche terminée ✓'), backgroundColor: Color(0xFF26C6A6)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    final task = widget.task;

    // Couleur statut
    final statusColor = task.status == TaskStatus.completed
        ? const Color(0xFF26C6A6)
        : task.status == TaskStatus.inProgress
            ? const Color(0xFFFFA726)
            : const Color(0xFF42A5F5);

    return Scaffold(
      backgroundColor: AppTheme.bg(isDark),
      appBar: AppBar(
        title: Text(task.reference, style: const TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.c2.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 20), text: 'Détails'),
            Tab(icon: Icon(Icons.lightbulb_outline, size: 20), text: 'Reco'),
            Tab(icon: Icon(Icons.photo_library_outlined, size: 20), text: 'Photos'),
            Tab(icon: Icon(Icons.videocam_outlined, size: 20), text: 'Vidéos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(isDark, task, statusColor),
          TaskRecommendationsWidget(
            taskName: task.name,
            taskDescription: task.description,
          ),
          _buildPhotosTab(isDark),
          _buildVideosTab(isDark),
        ],
      ),
      bottomNavigationBar: task.status != TaskStatus.completed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _markAsCompleted,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Marquer comme terminée', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.skyBottom,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── Onglet Détails ──────────────────────────────────────────────────────────
  Widget _buildDetailsTab(bool isDark, Task task, Color statusColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carte principale
          Container(
            width: double.infinity,
            decoration: AppTheme.cardBlue(radius: 20),
            child: Column(
              children: [
                // Header statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.6)),
                        ),
                        child: Text(task.status.label,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(task.reference,
                            style: TextStyle(color: AppTheme.c2.withOpacity(0.7), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                // Contenu
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(task.name,
                          style: const TextStyle(
                              color: AppTheme.c1, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3)),
                      const SizedBox(height: 20),
                      _detailRow(Icons.calendar_today_outlined, 'Date', task.partnerName),
                      const SizedBox(height: 12),
                      _detailRow(Icons.access_time_rounded, 'Heure', task.startTime.isNotEmpty ? task.startTime : '—'),
                      const SizedBox(height: 20),
                      // Description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.skyTop.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.description_outlined, size: 15, color: AppTheme.accent),
                              const SizedBox(width: 6),
                              Text('Description', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              task.description.isNotEmpty ? task.description : 'Aucune description disponible.',
                              style: TextStyle(color: AppTheme.c2, fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.c2.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text('$label : ', style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 13)),
        Expanded(
          child: Text(value, style: TextStyle(color: AppTheme.c1, fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Onglet Photos ───────────────────────────────────────────────────────────
  Widget _buildPhotosTab(bool isDark) {
    final images = _uploadedUrls.where((u) => !_isVideo(u)).toList();

    return Column(
      children: [
        // Boutons action
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Ajouter photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.skyLight,
                    side: const BorderSide(color: AppTheme.skyTop),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_selectedImages.isNotEmpty) ...[ 
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadAll,
                  icon: _isUploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_isUploading ? '...' : 'Envoyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.skyBottom,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Aperçu sélection locale
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _selectedImages.length,
              itemBuilder: (_, i) => _localImageThumb(_selectedImages[i], () {
                setState(() => _selectedImages.removeAt(i));
              }),
            ),
          ),
        // Grille photos uploadées
        Expanded(
          child: images.isEmpty
              ? _emptyState(Icons.photo_library_outlined, 'Aucune photo')
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: images.length,
                  itemBuilder: (_, i) => _uploadedImageThumb(images[i], isDark),
                ),
        ),
      ],
    );
  }

  // ── Onglet Vidéos ───────────────────────────────────────────────────────────
  Widget _buildVideosTab(bool isDark) {
    final videos = _uploadedUrls.where((u) => _isVideo(u)).toList();

    return Column(
      children: [
        // Boutons action
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library_outlined, size: 18),
                  label: const Text('Galerie'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.skyLight,
                    side: const BorderSide(color: AppTheme.skyTop),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideoCamera,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Caméra'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.skyLight,
                    side: const BorderSide(color: AppTheme.skyTop),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_selectedVideos.isNotEmpty) ...[ 
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadAll,
                  icon: _isUploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_isUploading ? '...' : 'Envoyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.skyBottom,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Aperçu sélection locale
        if (_selectedVideos.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _selectedVideos.length,
              itemBuilder: (_, i) => _localVideoThumb(_selectedVideos[i], () {
                setState(() => _selectedVideos.removeAt(i));
              }),
            ),
          ),
        // Liste vidéos uploadées
        Expanded(
          child: videos.isEmpty
              ? _emptyState(Icons.videocam_outlined, 'Aucune vidéo')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: videos.length,
                  itemBuilder: (_, i) => _uploadedVideoTile(videos[i], isDark, i),
                ),
        ),
      ],
    );
  }

  // ── Widgets helpers ─────────────────────────────────────────────────────────

  Widget _localImageThumb(XFile file, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          width: 80, height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(file.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2, right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _localVideoThumb(XFile file, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          width: 80, height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: Icon(Icons.videocam, color: AppTheme.c1, size: 32)),
        ),
        Positioned(
          top: 2, right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 4, left: 4,
          child: Text(
            file.name.length > 10 ? '${file.name.substring(0, 10)}...' : file.name,
            style: TextStyle(color: AppTheme.c2, fontSize: 9),
          ),
        ),
      ],
    );
  }

  Widget _uploadedImageThumb(String url, bool isDark) {
    final full = url.startsWith('http') ? url : '${Config.effectiveUrl}$url';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        full, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppTheme.darkCard.withOpacity(0.75),
          child: Icon(Icons.broken_image, color: AppTheme.c2.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _uploadedVideoTile(String url, bool isDark, int index) {
    final name = url.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardBlue(radius: 12),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.play_circle_outline, color: AppTheme.accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vidéo ${index + 1}', style: TextStyle(color: AppTheme.c1, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(name, style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.c2.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  bool _isVideo(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }
}


