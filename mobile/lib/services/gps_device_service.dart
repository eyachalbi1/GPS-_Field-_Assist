import 'dart:convert';
import 'package:http/http.dart' as http;

class GpsDeviceService {
  static const String _apiUrl = 'http://41.226.24.13:5000/api/gps-devices';

  Future<List<GpsModule>> fetchGpsModules() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => GpsModule.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load GPS modules: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching GPS modules: $e');
    }
  }
}

class GpsModule {
  final String name;
  final String subtitle;

  GpsModule({required this.name, required this.subtitle});

  factory GpsModule.fromJson(Map<String, dynamic> json) {
    return GpsModule(
      name: json['SerialNumber'] ?? 'Unknown Module',
      subtitle: json['EquipmentType'] ?? 'No description',
    );
  }
}
