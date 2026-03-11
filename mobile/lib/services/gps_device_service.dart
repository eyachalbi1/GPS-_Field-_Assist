
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GpsDevice {
  final String serialNumber;
  final String? simCardNumber;
  final String equipmentType;
  final String? passwordDevice;

  GpsDevice({
    required this.serialNumber,
    this.simCardNumber,
    required this.equipmentType,
    this.passwordDevice,
  });

  factory GpsDevice.fromJson(Map<String, dynamic> json) {
    return GpsDevice(
      serialNumber: json['SerialNumber']?.toString() ?? '',
      simCardNumber: json['SIMCardNumber']?.toString(),
      equipmentType: json['EquipmentType']?.toString() ?? '',
      passwordDevice: json['PasswordDevice']?.toString(),
    );
  }

  Map<String, String?> toMap() {
    return {
      'SerialNumber': serialNumber,
      'SIMCardNumber': simCardNumber,
      'EquipmentType': equipmentType,
      'PasswordDevice': passwordDevice,
    };
  }
}

/// Connection status for GPS API
enum GpsApiStatus { connected, error, loading }

class GpsApiConnectionInfo {
  final GpsApiStatus status;
  final String message;
  final DateTime? lastUpdate;
  final bool isUsingFallback;

  GpsApiConnectionInfo({
    required this.status,
    required this.message,
    this.lastUpdate,
    this.isUsingFallback = false,
  });
}

class GpsDeviceService {
  static const String _defaultApiUrl =
      'http://41.226.24.13:5000/api/gps-devices';
  static String get _apiUrl =>
      (String.fromEnvironment('GPS_DEVICES_API_URL', defaultValue: ''))
          .isNotEmpty
          ? String.fromEnvironment('GPS_DEVICES_API_URL')
          : '$_defaultApiUrl';

  static String? _lastEtag;
  static List<GpsDevice> _lastDevices = [];
  static final StreamController<List<GpsDevice>> _devicesController =
      StreamController.broadcast();
  static Timer? _autoRefreshTimer;

  /// Public stream to listen for updates (create/update/delete)
  static Stream<List<GpsDevice>> get devicesStream => _devicesController.stream;

  /// Fetch devices from the API. Returns cached devices on error.
  static Future<List<GpsDevice>> fetchDevices({Duration timeout = const Duration(seconds: 10)}) async {
    final uri = Uri.parse(_apiUrl);
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (_lastEtag != null) headers['If-None-Match'] = _lastEtag!;

      final resp = await http.get(uri).timeout(timeout);

      if (resp.statusCode == 200) {
        final body = resp.body.isNotEmpty ? json.decode(resp.body) : [];
        final List<dynamic> list = body is List ? body : [];
        final devices = list.map((e) => GpsDevice.fromJson(e as Map<String, dynamic>)).toList();
        _lastDevices = devices;
        final etag = resp.headers['etag'];
        if (etag != null && etag.isNotEmpty) _lastEtag = etag;
        _devicesController.add(_lastDevices);
        return _lastDevices;
      } else if (resp.statusCode == 304) {
        // Not modified
        return _lastDevices;
      } else {
        // Non-OK response -> return cached
        return _lastDevices;
      }
    } on SocketException {
      return _lastDevices;
    } on TimeoutException {
      return _lastDevices;
    } catch (e) {
      return _lastDevices;
    }
  }

  /// Start automatic periodic refresh; broadcasts changes on the stream.
  static void startAutoRefresh({Duration interval = const Duration(seconds: 15)}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) async {
      final devices = await fetchDevices();
      // If list changed (add/update/delete), broadcast (fetchDevices already broadcasts)
    });
  }

  /// Stop automatic refresh
  static void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Get last cached devices immediately
  static List<GpsDevice> getCachedDevices() => List.unmodifiable(_lastDevices);
 }
