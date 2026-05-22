import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class GpsDevice {
  final String serialNumber;
  final String? simCardNumber;
  final String equipmentType;
  final String? passwordDevice;
  final int equipmentStatus; // 0=FW check, 1=Config needed, 2=OK, 3=Diagnostic, 4=Manual

  GpsDevice({
    required this.serialNumber,
    this.simCardNumber,
    required this.equipmentType,
    this.passwordDevice,
    this.equipmentStatus = 2,
  });

  factory GpsDevice.fromJson(Map<String, dynamic> json) {
    return GpsDevice(
      serialNumber:    json['SerialNumber']?.toString() ?? '',
      simCardNumber:   json['SIMCardNumber']?.toString(),
      equipmentType:   json['EquipmentType']?.toString() ?? '',
      passwordDevice:  json['PasswordDevice']?.toString(),
      equipmentStatus: (json['EquipmentStatus'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'SerialNumber':    serialNumber,
      'SIMCardNumber':   simCardNumber,
      'EquipmentType':   equipmentType,
      'PasswordDevice':  passwordDevice,
      'EquipmentStatus': equipmentStatus,
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
  static String get _apiUrl => '${Config.apiBaseUrl}/api/gps-devices';  // 41.226.24.13:5000

  static String? _lastEtag;
  static List<GpsDevice> _lastDevices = [];
  static final StreamController<List<GpsDevice>> _devicesController =
      StreamController.broadcast();
  static Timer? _autoRefreshTimer;

  /// Public stream to listen for updates (create/update/delete)
  static Stream<List<GpsDevice>> get devicesStream => _devicesController.stream;

  static const _cacheKey = 'cached_gps_devices';

  static Future<void> _persistDevices(List<GpsDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _cacheKey, jsonEncode(devices.map((d) => d.toMap()).toList()));
  }

  static Future<List<GpsDevice>> _loadPersistedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => GpsDevice.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch devices from the API. Returns persisted devices on error.
  static Future<List<GpsDevice>> fetchDevices(
      {Duration timeout = const Duration(seconds: 10)}) async {
    // Load persisted on first call if memory cache empty
    if (_lastDevices.isEmpty) {
      _lastDevices = await _loadPersistedDevices();
      if (_lastDevices.isNotEmpty) _devicesController.add(_lastDevices);
    }

    final uri = Uri.parse(_apiUrl);
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (_lastEtag != null) headers['If-None-Match'] = _lastEtag!;

      final resp = await http.get(uri, headers: headers).timeout(timeout);

      if (resp.statusCode == 200) {
        final body = resp.body.isNotEmpty ? json.decode(resp.body) : [];
        final List<dynamic> list = body is List ? body : [];
        final devices = list
            .map((e) => GpsDevice.fromJson(e as Map<String, dynamic>))
            .toList();
        _lastDevices = devices;
        await _persistDevices(devices);
        final etag = resp.headers['etag'];
        if (etag != null && etag.isNotEmpty) _lastEtag = etag;
        _devicesController.add(_lastDevices);
        return _lastDevices;
      } else if (resp.statusCode == 304) {
        return _lastDevices;
      } else {
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
  static void startAutoRefresh(
      {Duration interval = const Duration(seconds: 15)}) {
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

  /// Update device status via API: GET /api/gps-devices/{imei}/{newStatus}
  static Future<bool> updateStatus(String imei, int newStatus) async {
    try {
      final url = '${Config.apiBaseUrl}/api/gps-devices/$imei/$newStatus';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
