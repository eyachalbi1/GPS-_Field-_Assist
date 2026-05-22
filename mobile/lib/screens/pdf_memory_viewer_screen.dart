import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _pageController = TextEditingController();
  int _totalPages = 0;
  int _currentPage = 1;

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

    return Column(
      children: [
        Container(
          color: Colors.blue.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Page', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 32,
                child: TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (v) {
                    final p = int.tryParse(v);
                    if (p != null && p >= 1 && p <= _totalPages) {
                      _pdfController.jumpToPage(p);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('/ $_totalPages', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: SfPdfViewer.memory(
            pdfBytes!,
            controller: _pdfController,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            canShowPaginationDialog: false,
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = details.document.pages.count;
                _currentPage = 1;
                _pageController.text = '1';
              });
            },
            onPageChanged: (details) {
              setState(() {
                _currentPage = details.newPageNumber;
                _pageController.text = '$_currentPage';
              });
            },
          ),
        ),
      ],
    );
  }
}



