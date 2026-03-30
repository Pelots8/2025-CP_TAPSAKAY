import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../driver/driver_service.dart';
import '../user/login_api.dart';

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  factory HardwareService() => _instance;
  HardwareService._internal();

  String? _esp8266Ip;
  bool _isConnected = false;
  Timer? _pollingTimer;
  StreamController<Map<String, dynamic>>? _gpsStreamController;
  
  // GPS data
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentSpeed;
  int? _satellites;
  bool _isMockData = false;
  String _connectionStatus = 'Disconnected';
  String? _driverId;

  // Getters
  Stream<Map<String, dynamic>> get gpsStream => 
      _gpsStreamController?.stream ?? Stream.empty();
  bool get isConnected => _isConnected;
  String? get connectedIP => _esp8266Ip;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  double? get currentSpeed => _currentSpeed;
  int? get satellites => _satellites;
  bool get isMockData => _isMockData;
  String get connectionStatus => _connectionStatus;

  Future<void> initialize() async {
    _gpsStreamController = StreamController<Map<String, dynamic>>.broadcast();
    
    // Get driver ID for database updates
    final userProfile = await LoginApi.getUserProfile();
    if (userProfile?['id'] != null) {
      _driverId = userProfile!['id'];
    }
    
    // Auto-discover hardware module
    await autoDiscover();
  }
  
  /// Auto-discover ESP8266 hardware module on the network
  Future<bool> autoDiscover() async {
    _connectionStatus = 'Searching for hardware...';
    print('=== Auto-discovering hardware module ===');
    
    // Method 1: Try mDNS hostname first
    String? ip = await _tryMDNS();
    if (ip != null) {
      return await connect(ip);
    }
    
    // Method 2: Scan local network
    ip = await _scanNetwork();
    if (ip != null) {
      return await connect(ip);
    }
    
    _connectionStatus = 'Hardware not found';
    return false;
  }
  
  /// Try mDNS hostname resolution
  Future<String?> _tryMDNS() async {
    try {
      print('Trying mDNS: tapsakay.local');
      final response = await http
          .get(Uri.parse('http://tapsakay.local/status'))
          .timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ip'] != null) {
          print('✅ Found via mDNS: ${data['ip']}');
          return data['ip'];
        }
      }
    } catch (e) {
      print('mDNS failed: $e');
    }
    return null;
  }
  
  /// Scan local network for hardware module
  Future<String?> _scanNetwork() async {
    try {
      print('Scanning network...');
      _connectionStatus = 'Scanning network...';
      
      // Get device's local IP
      final interfaces = await NetworkInterface.list();
      String? localIP;
      
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            localIP = addr.address;
            break;
          }
        }
      }
      
      if (localIP == null) {
        print('Could not determine local IP');
        return null;
      }
      
      print('Local IP: $localIP');
      final parts = localIP.split('.');
      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      
      // Scan IPs in parallel (batches of 50)
      for (int batch = 0; batch < 6; batch++) {
        final futures = <Future<String?>>[];
        final start = batch * 50 + 1;
        final end = (batch + 1) * 50;
        
        for (int i = start; i <= end && i <= 254; i++) {
          futures.add(_checkIP('$networkPrefix.$i'));
        }
        
        final results = await Future.wait(futures);
        for (var result in results) {
          if (result != null) {
            print('✅ Found via scan: $result');
            return result;
          }
        }
      }
    } catch (e) {
      print('Network scan failed: $e');
    }
    return null;
  }
  
  /// Check if IP is the hardware module
  Future<String?> _checkIP(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/status'))
          .timeout(const Duration(milliseconds: 300));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('gps_connected') && data.containsKey('wifi_connected')) {
          return ip;
        }
      }
    } catch (e) {
      // Ignore - IP not responding
    }
    return null;
  }

  // Connect to ESP8266
  Future<bool> connect(String ip) async {
    try {
      _esp8266Ip = ip;
      _connectionStatus = 'Connecting...';
      
      // Test connection
      final response = await http.get(
        Uri.parse('http://$ip/status'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _isConnected = true;
        _connectionStatus = 'Connected';
        print('Connected to ESP8266 at $ip');
        
        // Start polling GPS data
        _startPolling();
        return true;
      } else {
        _connectionStatus = 'Failed to connect';
        return false;
      }
    } catch (e) {
      print('Failed to connect: $e');
      _connectionStatus = 'Connection failed';
      _isConnected = false;
      return false;
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      await _fetchGPSData();
    });
  }

  Future<void> _fetchGPSData() async {
    if (!_isConnected || _esp8266Ip == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('http://$_esp8266Ip/gps'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        _currentLatitude = data['latitude'];
        _currentLongitude = data['longitude'];
        _currentSpeed = data['speed'];
        _satellites = data['satellites'];
        _isMockData = data['mock'] ?? false;
        
        // Send to Supabase if valid GPS and driver is on duty
        if (_driverId != null && _currentLatitude != null && _currentLongitude != null) {
          await DriverService.updateDriverLocation(
            driverId: _driverId!,
            latitude: _currentLatitude!,
            longitude: _currentLongitude!,
          );
        }
        
        _gpsStreamController?.add({
          'latitude': _currentLatitude,
          'longitude': _currentLongitude,
          'speed': _currentSpeed,
          'satellites': _satellites,
          'valid': data['valid'],
          'mock': _isMockData,
        });
      }
    } catch (e) {
      print('Error fetching GPS: $e');
      _connectionStatus = 'Error fetching data';
    }
  }

  // Get device status
  Future<Map<String, dynamic>?> getStatus() async {
    if (!_isConnected || _esp8266Ip == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('http://$_esp8266Ip/status'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getting status: $e');
    }
    return null;
  }

  // Disconnect
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _isConnected = false;
    _connectionStatus = 'Disconnected';
    _esp8266Ip = null;
  }

  void dispose() {
    disconnect();
    _gpsStreamController?.close();
  }
}
