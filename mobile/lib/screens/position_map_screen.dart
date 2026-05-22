import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PositionMapScreen extends StatefulWidget {
  final String moduleName;
  final String rawSms;

  const PositionMapScreen({
    super.key,
    required this.moduleName,
    required this.rawSms,
  });

  /// Convertit DDMM.MMMM → degrés décimaux
  static double _dmToDecimal(String raw) {
    final val = double.parse(raw);
    final deg = (val / 100).truncate();
    final min = val - deg * 100;
    return deg + min / 60;
  }

  /// Extrait lat/lng depuis n'importe quel format de réponse SMS
  static ({double lat, double lng})? extractCoords(String sms) {
    // ── Format EasyTrace VII : N3650.2041E01012.1872 (DDMM.MMMM collé) ──
    // Latitude  : N + 4 chiffres + . + chiffres  (ex: N3650.2041)
    // Longitude : E + 5 chiffres + . + chiffres  (ex: E01012.1872)
    final et7 = RegExp(r'[Nn](\d{4}\.\d+)[Ee](\d{5}\.\d+)');
    var m = et7.firstMatch(sms);
    if (m != null) {
      return (
        lat: _dmToDecimal(m.group(1)!),
        lng: _dmToDecimal(m.group(2)!),
      );
    }

    // ── Format EasyTraceX : ?q=N34.74075,E010.70366 (déjà décimal) ──
    final neFmt = RegExp(r'[?&]q=[Nn](-?\d{1,3}\.\d+),[Ee](\d{1,3}\.\d+)');
    m = neFmt.firstMatch(sms);
    if (m != null) {
      return (lat: double.parse(m.group(1)!), lng: double.parse(m.group(2)!));
    }

    // ── Bare N/E décimal ──
    final neBare = RegExp(r'[Nn](-?\d{1,3}\.\d+)[,\s]+[Ee](\d{1,3}\.\d+)');
    m = neBare.firstMatch(sms);
    if (m != null) {
      return (lat: double.parse(m.group(1)!), lng: double.parse(m.group(2)!));
    }

    // ── Fallback : coordonnées décimales brutes ──
    for (final reg in [
      RegExp(r'[?&]q=(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)'),
      RegExp(r'@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)'),
      RegExp(r'll=(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)'),
      RegExp(r'(-?\d{1,3}\.\d{4,})[,\s]+(-?\d{1,3}\.\d{4,})'),
    ]) {
      m = reg.firstMatch(sms);
      if (m != null) {
        try {
          final lat = double.parse(m.group(1)!);
          final lng = double.parse(m.group(2)!);
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            return (lat: lat, lng: lng);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extrait n'importe quel lien URL du SMS
  static String? extractAnyUrl(String sms) {
    final reg = RegExp(r'https?://[^\s]+', caseSensitive: false);
    return reg.firstMatch(sms)?.group(0);
  }

  @override
  State<PositionMapScreen> createState() => _PositionMapScreenState();
}

class _PositionMapScreenState extends State<PositionMapScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  late final ({double lat, double lng})? _coords;
  late final String? _anyUrl;

  @override
  void initState() {
    super.initState();
    _coords = PositionMapScreen.extractCoords(widget.rawSms);
    _anyUrl = PositionMapScreen.extractAnyUrl(widget.rawSms);

    final lat = _coords?.lat ?? 36.8065;
    final lng = _coords?.lng ?? 10.1815;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _loading = false); },
        onWebResourceError: (_) { if (mounted) setState(() => _loading = false); },
      ))
      ..loadHtmlString(_buildHtml(lat, lng, widget.moduleName));
  }

  String _buildHtml(double lat, double lng, String label) {
    final safeLabel = label.replaceAll("'", "\\'").replaceAll('"', '\\"');
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    html, body, #map { width:100%; height:100%; background:#1a1a2e; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var map = L.map('map', {zoomControl:true}).setView([$lat, $lng], 15);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap',
      maxZoom: 19,
      subdomains: ['a','b','c']
    }).addTo(map);
    var marker = L.circleMarker([$lat, $lng], {
      radius: 10,
      fillColor: '#DC143C',
      color: '#ffffff',
      weight: 2,
      opacity: 1,
      fillOpacity: 1
    }).addTo(map);
    marker.bindPopup('<b>$safeLabel</b><br>${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}').openPopup();
    // Pulse animation
    var pulse = L.circleMarker([$lat, $lng], {
      radius: 20,
      fillColor: '#DC143C',
      color: '#DC143C',
      weight: 1,
      opacity: 0.3,
      fillOpacity: 0.15
    }).addTo(map);
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.c1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Position du module', style: TextStyle(fontSize: 15)),
            Text(widget.moduleName,
                style: const TextStyle(fontSize: 12, color: AppTheme.c2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Ouvrir dans Google Maps',
            onPressed: () async {
              final url = _coords != null
                  ? 'https://www.google.com/maps?q=${_coords!.lat},${_coords!.lng}'
                  : _anyUrl;
              if (url != null) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: _coords != null
          ? _buildMap()
          : _buildNoCoords(),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF0C4D7A))),
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: AppTheme.cardBlue(radius: 12),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Color(0xFF48C9B0), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${_coords!.lat.toStringAsFixed(6)}   Lng: ${_coords!.lng.toStringAsFixed(6)}',
                    style: TextStyle(color: AppTheme.c1, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoCoords() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/fond tunav.jpg'), fit: BoxFit.cover),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardBlue(radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_searching, color: Color(0xFF48C9B0), size: 48),
              const SizedBox(height: 12),
              const Text(
                'Réponse SMS reçue',
                style: TextStyle(color: AppTheme.c1, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // SMS brut sélectionnable
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: widget.rawSms));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS copié'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.skyTop.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.rawSms,
                    style: TextStyle(color: AppTheme.c1, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bouton ouvrir le lien si présent
              if (_anyUrl != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    await launchUrl(Uri.parse(_anyUrl!), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Ouvrir le lien dans Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.skyBottom,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              if (_anyUrl == null)
                const Text(
                  'Aucun lien GPS détecté dans ce SMS.\nVérifiez que le module a bien reçu la commande *11*3#.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}



