import 'package:flutter/material.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'pdf_memory_viewer_screen.dart';
import 'ai_chat_screen.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allModules = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    setState(() { _loading = true; _error = null; });

    final list = await PdfService.fetchPdfList();
    if (!mounted) return;

    final modules = list.map<Map<String, dynamic>>((item) {
      final filename = item['filename'] ?? '';
      return {
        'filename': filename,
        'name': filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
        'imageUrl': '',
        'description': '',
      };
    }).where((e) => (e['filename'] as String).isNotEmpty).toList();

    setState(() {
      _allModules = modules;
      _filtered = _searchController.text.isEmpty ? modules : _filtered;
      _loading = false;
      _error = modules.isEmpty ? 'Aucun module disponible.' : null;
    });
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _allModules;
      } else {
        final q = query.toLowerCase();
        _filtered = _allModules
            .where((m) =>
                (m['name'] as String).toLowerCase().contains(q) ||
                (m['filename'] as String).toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _showDetails(Map<String, dynamic> module) {
    showDialog(
      context: context,
      builder: (ctx) => _ModuleDetailDialog(module: module),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = false;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: AppTheme.cardBlue(radius: 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.skyTop.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.skyBottom.withOpacity(0.35), width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un module...',
                      hintStyle: TextStyle(color: AppTheme.c2.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search, color: AppTheme.c2),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.refresh, color: AppTheme.c2),
                        onPressed: _loadModules,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
        // ── Bouton chatbot en haut à droite ──
        Positioned(
          top: 24,
          right: 24,
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.skyBottom.withOpacity(0.85),
                border: Border.all(color: AppTheme.skyLight.withOpacity(0.5), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppTheme.text(isDark)));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: AppTheme.textSubColor(isDark)),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppTheme.textSubColor(isDark)), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadModules, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) return Center(child: Text('Aucun module trouvé.', style: TextStyle(color: AppTheme.textSubColor(isDark))));
    final cardAspectRatio = MediaQuery.of(context).size.width < 420 ? 0.72 : 0.8;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: cardAspectRatio,
      ),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final module = _filtered[index];
        return GestureDetector(
          onTap: () => _showDetails(module),
          child: Container(
            decoration: AppTheme.cardBlue(radius: 16),
            child: LayoutBuilder(builder: (context, constraints) {
              final size = (constraints.maxWidth * 0.62).clamp(68.0, 100.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: AppTheme.surface(isDark).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ModuleImage(imageUrl: module['imageUrl'] as String, filename: module['filename'] as String, size: size),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      module['name'] as String,
                      style: TextStyle(color: AppTheme.text(isDark), fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Module image widget ──────────────────────────────────────────────────────

class _ModuleImage extends StatelessWidget {
  final String imageUrl;
  final String filename;
  final double size;

  const _ModuleImage({required this.imageUrl, required this.filename, required this.size});

  static String? _resolveLocalAsset(String filename) {
    final n = filename.toLowerCase();
    if (n.contains('et7') || (n.contains('easytrace') && (n.contains('vii') || n.contains('7')))) return 'assets/ET7.jpeg';
    if (n.contains('etx') || n.contains('easytracex') || n.contains('protocol')) return 'assets/MT02S-200.jpg';
    if (n.contains('et8') || n.contains('easytrace8') || n.contains('easytraceviii')) return 'assets/MT02S-200.jpg';
    if (n.contains('et6') || n.contains('easytrace6') || n.contains('easytracevi')) return 'assets/MT02S-200.jpg';
    if (n.contains('fm4200') || n.contains('fm42')) return 'assets/FM4200_v1.92.jpeg';
    if (n.contains('fm5300') || n.contains('fm53')) return 'assets/FM5300_ v3.4.jpeg';
    if (n.contains('fma120') || n.contains('fma12')) return 'assets/FMA120_v1.17.jpeg';
    if (n.contains('gt06')) return 'assets/GT06N.jpeg';
    if (n.contains('mt02') || n.contains('multitrace') || n.contains('gps') || n.contains('tracker')) return 'assets/MT02S-200.jpg';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localAsset = _resolveLocalAsset(filename);

    // Image réseau si disponible
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildLocal(localAsset),
      );
    }
    return _buildLocal(localAsset);
  }

  Widget _buildLocal(String? asset) {
    if (asset != null) {
      return Image.asset(
        asset, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Icon(Icons.gps_fixed, size: size * 0.5, color: AppTheme.c2.withOpacity(0.5));
}

// ── Module detail dialog ─────────────────────────────────────────────────────

class _ModuleDetailDialog extends StatefulWidget {
  final Map<String, dynamic> module;
  const _ModuleDetailDialog({required this.module});

  @override
  State<_ModuleDetailDialog> createState() => _ModuleDetailDialogState();
}

class _ModuleDetailDialogState extends State<_ModuleDetailDialog> {
  bool _loadingPdf = false;

  Future<void> _openPdf() async {
    final filename = widget.module['filename'] as String;
    final name = widget.module['name'] as String;

    setState(() => _loadingPdf = true);
    final bytes = await PdfService.getPdfBytes(
      filename,
      directUrl: '${PdfService.baseUrl}/api/download/$filename',
    );
    if (!mounted) return;
    setState(() => _loadingPdf = false);

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger: $name')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfMemoryViewerScreen(filename: filename, title: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final name = module['name'] as String;
    final filename = module['filename'] as String;
    final description = module['description'] as String;
    final imageUrl = module['imageUrl'] as String;
    final cached = PdfService.isCached(filename);

    return Dialog(
      backgroundColor: AppTheme.card(Theme.of(context).brightness == Brightness.dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(name,
                      style: TextStyle(color: AppTheme.c1, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _ModuleImage(imageUrl: imageUrl, filename: filename, size: 120),
              ),
            ),
            const SizedBox(height: 12),
            if (description.isNotEmpty)
              Text(description,
                  style: TextStyle(color: AppTheme.c2, fontSize: 14),
                  textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(filename,
                style: TextStyle(color: AppTheme.c2.withOpacity(0.5), fontSize: 11),
                textAlign: TextAlign.center),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _loadingPdf ? null : _openPdf,
              icon: _loadingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(cached ? Icons.picture_as_pdf : Icons.download),
              label: Text(_loadingPdf
                  ? 'Chargement...'
                  : cached
                      ? 'Ouvrir le manuel'
                      : 'Télécharger et ouvrir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.btnDark,
                foregroundColor: AppTheme.c1,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



