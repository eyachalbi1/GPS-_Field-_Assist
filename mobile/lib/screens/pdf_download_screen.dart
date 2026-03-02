import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'pdf_viewer_screen.dart';

class PdfDownloadScreen extends StatefulWidget {
  const PdfDownloadScreen({super.key});

  @override
  State<PdfDownloadScreen> createState() => _PdfDownloadScreenState();
}

class _PdfDownloadScreenState extends State<PdfDownloadScreen> {
  final List<Map<String, String>> _pdfFiles = [
    {
      'name': 'GPS Tracker Manual',
      'file': 'pdfs_modules/GPSTrackerManual-2016.pdf'
    },
    {
      'name': 'EasyCan Instructions',
      'file': 'pdfs_modules/5040189801 Ist.Uso EasyCan (1).pdf'
    },
    {
      'name': 'EasyCan Digital Manual',
      'file': 'pdfs_modules/5040190400-is-mn-easycan-digital.pdf'
    },
    {'name': 'Module 5227793', 'file': 'pdfs_modules/5227793.pdf'},
  ];

  Future<void> _downloadPdf(String pdfPath, String pdfName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement en cours...')),
      );

      ByteData data = await rootBundle.load(pdfPath);
      List<int> bytes = data.buffer.asUint8List();

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        directory = Directory('${directory!.path}/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String fileName = '$pdfName.pdf';
      File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF téléchargé: ${file.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _viewPdf(String pdfPath) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfPath: pdfPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Téléchargement de PDFs'),
        backgroundColor: const Color(0xFF0066FF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fond tunav.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pdfFiles.length,
          itemBuilder: (context, index) {
            final pdf = _pdfFiles[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFE74C3C),
                  size: 32,
                ),
                title: Text(
                  pdf['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: SizedBox(
                  width: 180,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _viewPdf(pdf['file']!),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Voir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _downloadPdf(pdf['file']!, pdf['name']!),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Télécharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
