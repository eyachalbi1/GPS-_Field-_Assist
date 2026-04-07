import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/pdf_service.dart';

class PdfMemoryViewerScreen extends StatefulWidget {
  final String filename;
  final String title;

  const PdfMemoryViewerScreen({
    super.key,
    required this.filename,
    this.title = 'Visualiseur PDF',
  });

  @override
  State<PdfMemoryViewerScreen> createState() => _PdfMemoryViewerScreenState();
}

class _PdfMemoryViewerScreenState extends State<PdfMemoryViewerScreen> {
  Uint8List? pdfBytes;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final bytes = await PdfService.getPdfBytes(widget.filename);
    if (mounted) {
      setState(() {
        pdfBytes = bytes;
        isLoading = false;
        if (bytes == null) {
          error = 'Impossible de charger le PDF: ${widget.filename}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.c1,
        actions: [
          if (pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPdf,
              tooltip: 'Recharger',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du PDF...'),
          ],
        ),
      );
    }

    if (error != null || pdfBytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(error ?? 'Erreur inconnue', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.skyBottom,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SfPdfViewer.memory(pdfBytes!);
  }
}



