import 'package:flutter/material.dart';
import 'module_config_screen.dart';
import '../services/gps_device_service.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _searchController = TextEditingController();
  String _selectedSection = 'update';
  List<_GpsModule> _modules = [];
  List<_GpsModule> _apiModules = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const List<_GpsModule> _staticModules = [
    _GpsModule(name: 'Module GPS-001', subtitle: 'Mise a jour du firmware'),
    _GpsModule(name: 'Module GPS-002', subtitle: 'Mise a jour du firmware'),
    _GpsModule(name: 'Module GPS-003', subtitle: 'Mise a jour du firmware'),
    _GpsModule(name: 'Module GPS-004', subtitle: 'Mise a jour du firmware'),
  ];

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gpsDeviceService = GpsDeviceService();
      final apiModules = await gpsDeviceService.fetchGpsModules();

      // Convert API modules to _GpsModule format
      final apiGpsModules = apiModules
          .map((module) =>
              _GpsModule(name: module.name, subtitle: module.subtitle))
          .toList();

      setState(() {
        _apiModules = apiGpsModules;
        _modules = _apiModules; // Only show API modules
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _modules = _staticModules; // Fallback to static modules
        _isLoading = false;
      });
    }
  }

  void _scanQR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Scanner QR ouvert'), backgroundColor: Colors.blue),
    );
  }

  List<_GpsModule> get _filteredModules {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _modules;
    }
    return _modules
        .where((module) =>
            module.name.toLowerCase().contains(query) ||
            module.subtitle.toLowerCase().contains(query))
        .toList();
  }

  void _onModuleAction(_GpsModule module) {
    if (_selectedSection == 'config') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ModuleConfigScreen(moduleName: module.name),
        ),
      );
      return;
    }

    final message = _selectedSection == 'update'
        ? 'Update lancee pour ${module.name}'
        : 'Diagnostic ouvert pour ${module.name}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF3498DB)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un module...',
                        hintStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.search, color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanQR,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'Scanner QR',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSectionButton(
                      'Mise a jour', 'update', Icons.system_update_alt),
                ),
                Expanded(
                  child: _buildSectionButton(
                      'Configuration', 'config', Icons.settings),
                ),
                Expanded(
                  child: _buildSectionButton(
                      'Diagnostique', 'diagnostic', Icons.health_and_safety),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: _filteredModules.isEmpty && !_isLoading
                  ? const Center(
                      child: Text(
                        'Aucun module trouve',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredModules.length,
                      itemBuilder: (context, index) {
                        final module = _filteredModules[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 360;

                              final info = Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.memory,
                                        color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          module.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          module.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final actionButton = ElevatedButton(
                                onPressed: () => _onModuleAction(module),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3C9EE6),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(104, 40),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  _getActionLabel(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    info,
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: actionButton,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: info),
                                  const SizedBox(width: 10),
                                  actionButton,
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionButton(String label, String section, IconData icon) {
    final isSelected = _selectedSection == section;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSection = section);
        if (section == 'config') {
          _loadModules(); // Refresh modules when config section is selected
        } else if (section == 'update') {
          // Show static modules for update
          setState(() {
            _modules = _staticModules;
          });
        } else if (section == 'diagnostic') {
          // Show static modules for diagnostic
          setState(() {
            _modules = _staticModules;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF48C9B0).withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF48C9B0) : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF48C9B0) : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel() {
    switch (_selectedSection) {
      case 'update':
        return 'Update';
      case 'config':
        return 'Configurer';
      case 'diagnostic':
        return 'Ouvrir';
      default:
        return 'Ouvrir';
    }
  }
}

class _GpsModule {
  final String name;
  final String subtitle;

  const _GpsModule({
    required this.name,
    required this.subtitle,
  });
}
