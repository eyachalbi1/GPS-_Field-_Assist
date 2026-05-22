import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/pdf_service.dart';
import 'pdf_memory_viewer_screen.dart';

class PdfDownloadScreen extends StatefulWidget {
  const PdfDownloadScreen({super.key});

  @override
  State<PdfDownloadScreen> createState() => _PdfDownloadScreenState();
}

class _PdfDownloadScreenState extends State<PdfDownloadScreen> {
  List<Map<String, String>> _pdfFiles = [];
  bool _loadingList = true;
  String? _listError;
  final Set<String> _opening = {};

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    final files = await PdfService.fetchPdfList();
    if (!mounted) return;
    setState(() {
      _pdfFiles = files;
      _loadingList = false;
      if (files.isEmpty) _listError = 'Aucun PDF disponible sur le serveur.';
    });
  }

  Future<void> _openPdf(String filename, String name) async {
    setState(() => _opening.add(filename));
    final bytes = await PdfService.getPdfBytes(filename);
    if (!mounted) return;
    setState(() => _opening.remove(filename));

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuels PDF'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadList,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_listError!),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.skyBottom,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pdfFiles.length,
      itemBuilder: (context, index) {
        final pdf = _pdfFiles[index];
        final filename = pdf['filename']!;
        final name = pdf['name']!;
        final isOpening = _opening.contains(filename);
        final cached = PdfService.isCached(filename);

        final isGv300can = filename.toLowerCase().contains('gv300can');
        return ListTile(
          leading: isGv300can
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/gv300can-gps.jpg.jpeg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.picture_as_pdf,
                      color: cached ? Colors.green : Colors.red,
                    ),
                  ),
                )
              : Icon(
                  Icons.picture_as_pdf,
                  color: cached ? Colors.green : Colors.red,
                ),
          title: Text(name),
          subtitle: Text(filename, style: const TextStyle(fontSize: 11)),
          trailing: isOpening
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(cached ? Icons.check_circle : Icons.download,
                  color: cached ? Colors.green : null),
          onTap: isOpening ? null : () => _openPdf(filename, name),
        );
      },
    );
  }
}