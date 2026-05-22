import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class PdfService {
  static final Map<String, Uint8List> _cache = {};
  static const _listKey = 'cached_pdf_list';

  static String get _base => Config.apiBaseUrl;  // 41.226.24.13:5000
  static String get baseUrl => Config.apiBaseUrl;

  static Future<Directory> get _pdfDir async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
    return pdfDir;
  }

  /// Fetch list of PDFs — falls back to cached list if offline
  static Future<List<Map<String, String>>> fetchPdfList() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/api/files'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        // API returns {"files": ["name.pdf", ...]}  — plain strings
        final List<dynamic> raw =
            decoded is List ? decoded : (decoded['files'] as List? ?? []);
        final list = raw.map<Map<String, String>>((item) {
          final filename = item is Map
              ? (item['filename'] ?? item['name'] ?? '').toString()
              : item.toString();
          return {'filename': filename, 'name': filename};
        }).where((e) => e['filename']!.isNotEmpty).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_listKey, jsonEncode(list));
        return list;
      }
    } catch (e) {
      debugPrint('PdfService.fetchPdfList error: $e');
    }
    return await _loadCachedList();
  }

  static Future<List<Map<String, String>>> _loadCachedList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_listKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get PDF bytes — persists to disk on first download
  static Future<Uint8List?> getPdfBytes(String filename, {String? directUrl}) async {
    if (_cache.containsKey(filename)) return _cache[filename];

    // Check disk cache
    final dir = await _pdfDir;
    final safe = filename.replaceAll('/', '_').replaceAll('\\', '_');
    final file = File('${dir.path}/$safe');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      _cache[filename] = bytes;
      return bytes;
    }

    // API uses /api/download/{filename}  (not /api/files/download/)
    final encoded = Uri.encodeComponent(filename);
    final url = directUrl ?? '$_base/api/download/$encoded';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);
        _cache[filename] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('PDF fetch error [$url]: $e');
    }
    return null;
  }

  static bool isCached(String filename) => _cache.containsKey(filename);
  static void clearCache() => _cache.clear();
}
