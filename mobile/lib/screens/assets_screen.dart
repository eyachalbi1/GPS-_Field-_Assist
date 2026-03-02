import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/config.dart';

class GpsDevice {
  final String name;
  final String imei;
  final String description;
  final List<String> features;
  final String pdfPath;
  final String imagePath;

  GpsDevice({
    required this.name,
    required this.imei,
    required this.description,
    required this.features,
    required this.pdfPath,
    required this.imagePath,
  });
}

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _searchController = TextEditingController();
  List<GpsDevice> _filteredDevices = [];

  final List<GpsDevice> _allDevices = [
    GpsDevice(
      name: 'ETCAN_KIT',
      imei: 'EasyCan Trace',
      description: 'Module GPS CAN-bus pour véhicules',
      features: [
        'Installation CAN-Bus',
        'Configuration GPS/GSM',
        'Fonction alarmes et tracking',
        'Configuration des protocoles véhicule'
      ],
      pdfPath: 'pdfs_modules/5040189801 Ist.Uso EasyCan.pdf',
      imagePath: 'assets/modules_gps/ETCAN_KIT.png',
    ),
    GpsDevice(
      name: 'MiniTrace_KIT',
      imei: 'Mini Trace GPS',
      description: 'Petit tracker GPS compact',
      features: [
        'Installation SIM',
        'Commandes SMS',
        'Localisation en temps réel',
        'Mode veille / économie batterie'
      ],
      pdfPath: 'pdfs_modules/GPSTrackerManual-2016.pdf',
      imagePath: 'assets/modules_gps/MiniTrace_KIT.png',
    ),
    GpsDevice(
      name: 'Camtrack',
      imei: 'Camtrack GPS',
      description: 'GPS avec caméra intégrée',
      features: [
        'Tracking GPS en temps réel',
        'Transmission GSM / GPRS',
        'Historique des positions',
        'Surveillance vidéo intégrée'
      ],
      pdfPath: 'pdfs_modules/5227793.pdf',
      imagePath: 'assets/modules_gps/Camtrack.png',
    ),
    GpsDevice(
      name: 'SMART_LOCK',
      imei: 'Smart Lock GPS',
      description: 'GPS cadenas intelligent',
      features: [
        'Localisation anti-vol',
        'Suivi en temps réel',
        'Alarmes mouvement',
        'Configuration SMS / plateforme'
      ],
      pdfPath:
          'pdfs_modules/495734027-Mode-d-emploi-Traceur-GPS-tracking-GPRS-GSM-SOS-voiture-animaux-support-aimant.pdf',
      imagePath: 'assets/modules_gps/SMART_lo.png',
    ),
    GpsDevice(
      name: 'ET6_KIT',
      imei: 'ET6 GPS Tracker',
      description: 'GPS tracker filaire',
      features: [
        'Schéma câblage',
        'Installation véhicule',
        'Configuration SIM',
        'Transmission GPS/GSM'
      ],
      pdfPath: 'pdfs_modules/easytrack.pdf',
      imagePath: 'assets/modules_gps/ET6_KIT.png',
    ),
    GpsDevice(
      name: 'ET8_KIT',
      imei: 'ET8 GPS Tracker',
      description: 'ET8 GPS tracker GSM',
      features: [
        'Installation GSM',
        'Configuration serveur',
        'Tracking temps réel',
        'Historique GPS'
      ],
      pdfPath: 'pdfs_modules/5227793.pdf',
      imagePath: 'assets/modules_gps/ET8_KIT.png',
    ),
    GpsDevice(
      name: 'ETBLE_KIT',
      imei: 'ETBLE GPS BLE',
      description: 'Tracker GPS + BLE',
      features: [
        'Bluetooth Low Energy',
        'GPS tracking',
        'Configuration BLE',
        'Économie d\'energie'
      ],
      pdfPath: 'pdfs_modules/easytrack.pdf',
      imagePath: 'assets/modules_gps/ETBLE_KIT.png',
    ),
    GpsDevice(
      name: 'ETX_KIT',
      imei: 'ETX GPS Tracker',
      description: 'Tracker GPS avec faisceau pour voiture',
      features: [
        'Installation véhicule',
        'Câblage complet',
        'GPS/GSM',
        'Alarmes intégrées'
      ],
      pdfPath: 'pdfs_modules/GPSTrackerManual-2016.pdf',
      imagePath: 'assets/modules_gps/ETX_KIT.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredDevices = _allDevices;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDevices(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDevices = _allDevices;
      } else {
        _filteredDevices = _allDevices.where((device) {
          return device.name.toLowerCase().contains(query.toLowerCase()) ||
              device.imei.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showDeviceDetails(GpsDevice device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C3E50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _buildDeviceImage(device),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                device.description,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'IMEI: ${device.imei}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: device.features.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF27AE60), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            device.features[index],
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final String pdfPath = device.pdfPath;

                  // If running on web, do not attempt to open or download PDFs.
                  if (kIsWeb) {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: const Color(0xFF2C3E50),
                        insetPadding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 160,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                      'Les PDF ne sont pas disponibles sur la version web de l\'application.',
                                      style: TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center),
                                  SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    return;
                  }

                  // For mobile/desktop, load the PDF from bundled assets.
                  String assetPath = pdfPath;
                  if (!assetPath.startsWith('pdfs_modules/') &&
                      !assetPath.startsWith('assets/')) {
                    final parts = assetPath.split(RegExp(r'[\\/]'));
                    final name = parts.isNotEmpty ? parts.last : assetPath;
                    assetPath = 'pdfs_modules/$name';
                  }

                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: const Color(0xFF2C3E50),
                      insetPadding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: SfPdfViewer.asset(assetPath),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Manuel d\'utilisation (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardAspectRatio =
        MediaQuery.of(context).size.width < 420 ? 0.72 : 0.8;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterDevices,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher par IMEI, GPS ou nom de voiture...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cardAspectRatio,
              ),
              itemCount: _filteredDevices.length,
              itemBuilder: (context, index) {
                final device = _filteredDevices[index];
                return GestureDetector(
                  onTap: () => _showDeviceDetails(device),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final imageSize =
                            (constraints.maxWidth * 0.62).clamp(68.0, 100.0);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: imageSize,
                              width: imageSize,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildDeviceImage(
                                  device,
                                  width: imageSize,
                                  height: imageSize,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                device.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                device.imei,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceImage(GpsDevice device, {double? width, double? height}) {
    // Build candidate filenames based on device name and imagePath
    final baseNameFromDevice = device.name.replaceAll(' ', '_');
    final candidates = <String>[];
    candidates.add('modules_gps/${baseNameFromDevice}.png');
    candidates.add('modules_gps/${baseNameFromDevice.toUpperCase()}.png');
    candidates.add('modules_gps/${baseNameFromDevice.toLowerCase()}.png');
    // also try the filename from imagePath
    final imagePathName = device.imagePath.split('/').last;
    candidates.add('modules_gps/$imagePathName');

    // network counterparts
    final networkCandidates = candidates
        .map((p) => '${Config.effectiveUrl}/modules/${p.split('/').last}')
        .toList();

    Widget buildNetworkFallback(int idx) {
      if (idx >= networkCandidates.length) {
        // final fallback to original asset path
        return Image.asset(
          device.imagePath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (c2, e2, s2) => Icon(Icons.gps_fixed,
              size: width != null ? width / 2 : 60,
              color: Colors.white.withOpacity(0.7)),
        );
      }
      return Image.network(
        networkCandidates[idx],
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => buildNetworkFallback(idx + 1),
      );
    }

    Widget buildFallbackAsset(int idx) {
      if (idx >= candidates.length) {
        // try network candidates sequentially
        return buildNetworkFallback(0);
      }
      return Image.asset(
        candidates[idx],
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => buildFallbackAsset(idx + 1),
      );
    }

    return buildFallbackAsset(0);
  }
}
