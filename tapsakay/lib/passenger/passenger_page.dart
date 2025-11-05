import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tapsakay/passenger/passenger_tap_service.dart';
import 'package:tapsakay/passenger/profile_page.dart';
import 'package:tapsakay/passenger/trip_history_page.dart';
import '../user/login_api.dart';
import '../services/bus_service.dart';
import '../services/user_service.dart';


class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(6.9214, 122.0790); // Zamboanga City default
  bool _isLoadingLocation = true;
  String _userName = '';
  double _currentZoom = 15.0;
  List<Map<String, dynamic>> _activeBuses = [];
  bool _isLoadingBuses = true;
  RealtimeChannel? _busesChannel;
  List<Map<String, dynamic>> _userNFCCards = [];
  bool _isLoadingCards = true;
  Map<String, dynamic>? _currentPassengerTrip;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _getCurrentLocation();
    _loadActiveBuses();
    _subscribeToActiveBuses();
    _loadUserNFCCards();
    _loadCurrentPassengerTrip();
    _subscribeToPassengerTripUpdates();
  }

  @override
  void dispose() {
    _busesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActiveBuses() async {
    try {
      setState(() => _isLoadingBuses = true);
      final buses = await BusService.getActiveBuses();
      setState(() {
        _activeBuses = buses;
        _isLoadingBuses = false;
      });
    } catch (e) {
      print('Error loading active buses: $e');
      setState(() => _isLoadingBuses = false);
    }
  }

  Future<void> _loadCurrentPassengerTrip() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final trip = await PassengerTapService.getCurrentPassengerTrip(userId);
        setState(() {
          _currentPassengerTrip = trip;
        });
      } else {
      }
    } catch (e) {
      print('Error loading current trip: $e');
    }
  }

  void _subscribeToPassengerTripUpdates() {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  
  // Subscribe to updates on passenger's trips
  Supabase.instance.client
    .channel('passenger-trip-updates-$userId')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'passenger_trips',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'passenger_id',
        value: userId,
      ),
      callback: (payload) async {
        // Reload current trip when updated
        await _loadCurrentPassengerTrip();
        
        // Show notification if driver confirmed
        final newRecord = payload.newRecord;
        if (newRecord['driver_confirmed'] == true && mounted) {
          final passengerCount = newRecord['passenger_count'] ?? 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                passengerCount > 1
                    ? 'Driver confirmed: $passengerCount passengers'
                    : 'Driver confirmed your boarding',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    )
    .subscribe();
}

  void _subscribeToActiveBuses() {
    _busesChannel = BusService.subscribeToActiveBuses(
      onUpdate: (buses) {
        if (mounted) {
          setState(() {
            _activeBuses = buses;
          });
        }
      },
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await LoginApi.getUserProfile();
      setState(() {
        _userName = profile?['full_name'] ?? 'Passenger';
      });
    } catch (e) {
      setState(() {
        _userName = 'Passenger';
      });
    }
  }

  Future<void> _loadUserNFCCards() async {
  try {
    setState(() => _isLoadingCards = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final cards = await UserService.getUserNFCCards(userId);
      setState(() {
        _userNFCCards = cards;
        _isLoadingCards = false;
      });
    } else {
      setState(() => _isLoadingCards = false);
    }
  } catch (e) {
    print('Error loading NFC cards: $e');
    setState(() => _isLoadingCards = false);
  }
} 

String _formatDuration(String tapInTimeStr) {
  try {
    final tapInTime = DateTime.parse(tapInTimeStr).toLocal();
    final now = DateTime.now();
    final duration = now.difference(tapInTime);
    
    if (duration.isNegative) return '0 min';
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  } catch (e) {
    return 'N/A';
  }
}

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move map to current location
      _mapController.move(_currentLocation, _currentZoom);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await LoginApi.logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _centerOnCurrentLocation() {
    _mapController.move(_currentLocation, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final maxWidth = isDesktop ? 500.0 : double.infinity;
    return Scaffold(
      
      body: Stack(
        children: [
          // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: _currentZoom,
            minZoom: 1.0,  // Add this
            maxZoom: 18.0, // Add this
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              }
            },
          ),
          children: [
              // OpenStreetMap Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tapsakay.app',
              ),
              
              // Active Buses Markers
              MarkerLayer(
                markers: _activeBuses.map((driver) {
                  // Get bus data
                  final bus = driver['buses'];
                  if (bus == null) return null;
                  
                  // Use driver's current location if available
                  final lat = driver['current_latitude'];
                  final lng = driver['current_longitude'];
                  
                  if (lat == null || lng == null) return null;
                  
                  final location = LatLng(lat.toDouble(), lng.toDouble());
                  
                  return Marker(
                    point: location,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showBusInfo(driver),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).whereType<Marker>().toList(),
              ),
              
              // Current Location Marker
              if (!_isLoadingLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top App Bar
          Positioned(
            top: 0,
            left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  },
  child: Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.blue[50],
      shape: BoxShape.circle,
      border: Border.all(color: Colors.blue[200]!, width: 2),
    ),
    child: Center(
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
        style: TextStyle(
          color: Colors.blue[700],
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ),
  ),
),

// Tap Out Button (show only when passenger has ongoing trip)
if (_currentPassengerTrip != null)
  Positioned(
    top: 100,
    left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 + 16 : 16,
    right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 + 16 : 16,
    child: SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Currently on trip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _currentPassengerTrip!['trips']['buses']['bus_number'] ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _handleTapOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tap Out'),
            ),
          ],
        ),
      ),
    ),
  ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $_userName!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Find your ride',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.grey[800]),
                      onPressed: () => _showMenu(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Buttons
          Positioned(
            right: 16,
            bottom: 150,
            child: Column(
              children: [
                // Zoom in button
                SizedBox(
                  width: 36,
                  height: 36,
                  child: FloatingActionButton(
                    heroTag: 'zoomIn',
                    backgroundColor: Colors.white,
                    elevation: 2,
                    onPressed: () {
                      setState(() {
                        _currentZoom = (_currentZoom + 1).clamp(1.0, 18);
                      });
                      _mapController.move(_currentLocation, _currentZoom);
                    },
                    child: Icon(Icons.add, color: Colors.grey[800], size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom out button
                SizedBox(
                  width: 36,
                  height: 36,
                  child: FloatingActionButton(
                    heroTag: 'zoomOut',
                    backgroundColor: Colors.white,
                    elevation: 2,
                    onPressed: () {
                      setState(() {
                        _currentZoom = (_currentZoom - 1).clamp(1.0, 18);
                      });
                      _mapController.move(_currentLocation, _currentZoom);
                    },
                    child: Icon(Icons.remove, color: Colors.grey[800], size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                // Center on location button (larger)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FloatingActionButton(
                    heroTag: 'center',
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _centerOnCurrentLocation,
                    child: Icon(Icons.my_location, color: Colors.blue[700], size: 28),
                  ),
                ),
              ],
            ),
          ),

// Bottom Sheet - Show Current Trip, Nearby Bus, or Active Buses
Positioned(
  bottom: 0,
  left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
  right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
  child: _currentPassengerTrip != null
      ? _buildOnboardSheet() // Passenger is already on a trip
      : _getNearestBus() != null
          ? _buildBoardBusSheet(_getNearestBus()!) // Bus is nearby (≤5m)
          : _buildActiveBusesSheet(), // Show all active buses
),
        ],
      ),
    );
  }

    // Add this helper method in your _PassengerHomeState class
    double _calculateDistance(LatLng busLocation) {
      return Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        busLocation.latitude,
        busLocation.longitude,
      ); // Returns distance in meters
    }

    String _formatDistance(double meters) {
      if (meters < 1000) {
        return '${meters.round()} m';
      } else {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
    }
    
    bool _isNearBus(Map<String, dynamic> driver) {
  final lat = driver['current_latitude'];
  final lng = driver['current_longitude'];
  
  if (lat == null || lng == null) return false;
  
  final distance = Geolocator.distanceBetween(
    _currentLocation.latitude,
    _currentLocation.longitude,
    lat.toDouble(),
    lng.toDouble(),
  );
  
  // Check if within 5 meters
  return distance <= 5500.0;
}

Map<String, dynamic>? _getNearestBus() {
  for (var driver in _activeBuses) {
    if (_isNearBus(driver)) {
      return driver;
    }
  }
  return null;
}

// Build Active Buses Sheet (original bottom sheet)
Widget _buildActiveBusesSheet() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Active Buses Nearby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_activeBuses.length} Online',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoadingBuses
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : _activeBuses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No active buses nearby',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 95,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _activeBuses.length,
                      itemBuilder: (context, index) {
                        final driver = _activeBuses[index];
                        final bus = driver['buses'];
                        if (bus == null) return const SizedBox.shrink();
                        
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      bus['bus_number'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bus['route_name'] ?? 'No route',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatDistance(_calculateDistance(
                                        LatLng(
                                          driver['current_latitude'].toDouble(),
                                          driver['current_longitude'].toDouble(),
                                        ),
                                      )),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ],
    ),
  );
}

// Build Board Bus Sheet (when passenger is near a bus)
Widget _buildBoardBusSheet(Map<String, dynamic> driver) {
  final bus = driver['buses'];
  final driverUser = driver['users'];
  final distance = _calculateDistance(
    LatLng(
      driver['current_latitude'].toDouble(),
      driver['current_longitude'].toDouble(),
    ),
  );
  
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.blue[700]!, Colors.blue[500]!],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BUS NEARBY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Bus Info
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus['bus_number'] ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    bus['route_name'] ?? 'No route',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  if (driverUser != null)
                    Text(
                      'Driver: ${driverUser['full_name']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Distance indicator
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: Colors.white.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Text(
                _formatDistance(distance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' away',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Board Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _handleTapIn(driver),
            icon: const Icon(Icons.login, color: Colors.blue),
            label: const Text(
              'Board This Bus',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // View other buses button
        TextButton(
          onPressed: () {
            setState(() {
              // Force show all buses by temporarily disabling geofence check
              // You can implement a flag like _showAllBuses if needed
            });
          },
          child: Text(
            'View all active buses',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

// Build Onboard Sheet (when passenger has active trip)
Widget _buildOnboardSheet() {
  final trip = _currentPassengerTrip!['trips'];
  final bus = trip['buses'];
  final nfcCard = _currentPassengerTrip!['nfc_cards'];

  
  // 🚀 Check if driver has confirmed
  final isConfirmed = _currentPassengerTrip!['driver_confirmed'] == true;
  final passengerCount = _currentPassengerTrip!['passenger_count'] ?? 1;
  
  // 🚀 If not confirmed, show waiting state
  if (!isConfirmed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[700]!, Colors.orange[500]!],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'WAITING FOR DRIVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bus Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus['bus_number'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      bus['route_name'] ?? 'No route',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Waiting message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.white.withOpacity(0.9), size: 32),
                const SizedBox(height: 8),
                Text(
                  'Driver is confirming your boarding',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Info text
          Text(
            'The driver will confirm the number of passengers traveling with you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: null, // Disabled
              icon: Icon(Icons.exit_to_app, color: Colors.grey[400]),
              label: Text(
                'Waiting for Confirmation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                disabledBackgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 🚀 Confirmed state - show normal onboard UI
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.green[700]!, Colors.green[500]!],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                passengerCount > 1 
                    ? 'ON BOARD ($passengerCount passengers)' 
                    : 'ON BOARD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Bus Info
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus['bus_number'] ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    bus['route_name'] ?? 'No route',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Trip Info Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.access_time, color: Colors.white.withOpacity(0.9), size: 20),
                    const SizedBox(height: 4),
                      Text(
                        _formatDuration(_currentPassengerTrip!['tap_in_time']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Duration',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.credit_card, color: Colors.white.withOpacity(0.9), size: 20),
                    const SizedBox(height: 4),
                    Text(
                      '₱${(nfcCard['balance'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        // 🚀 Show passenger count if > 1
        if (passengerCount > 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, color: Colors.white.withOpacity(0.9), size: 20),
                const SizedBox(width: 8),
                Text(
                  '$passengerCount passengers traveling together',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Tap Out Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _handleTapOut,
            icon: const Icon(Icons.exit_to_app, color: Colors.green),
            label: const Text(
              'Tap Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

 void _showBusInfo(Map<String, dynamic> driver) {
  final bus = driver['buses'];
  if (bus == null) return;
  
  final driverUser = driver['users'];
  final distance = _calculateDistance(
    LatLng(
      driver['current_latitude'].toDouble(),
      driver['current_longitude'].toDouble(),
    ),
  );
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.blue[700],
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus['bus_number'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bus['route_name'] ?? 'No route',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (driverUser != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Driver: ${driverUser['full_name']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(distance),
                          style: TextStyle(
                            fontSize: 12,
                            color: distance <= 5.0 ? Colors.green[700] : Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'away',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'On Duty',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Show different button based on distance
          if (distance <= 5.0) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleTapIn(driver);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Board This Bus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Get closer to the bus to board (within 5m)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  


Future<void> _handleTapIn(Map<String, dynamic> driver) async {
  
  
  // Check if user has NFC cards
  if (_userNFCCards.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No NFC card found. Please register a card first.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Get first active, non-blocked card
  final activeCard = _userNFCCards.firstWhere(
    (card) => card['is_active'] == true && card['is_blocked'] != true,
    orElse: () => {},
  );
  
  if (activeCard.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No active NFC card found.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  // Get current location
  Position position = await Geolocator.getCurrentPosition();
  
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  
  // Get trip from driver
  final driverTrip = driver['current_trip_id'];
  if (driverTrip == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Driver has no active trip'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  try {
    final result = await PassengerTapService.tapIn(
      passengerId: userId,
      nfcCardId: activeCard['id'],
      tripId: driverTrip,
      busId: driver['buses']['id'],
      driverId: driver['id'],
      latitude: position.latitude,
      longitude: position.longitude,
    );
    
if (result['success']) {
  // Show waiting for confirmation message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(result['message']),
          ),
        ],
      ),
      backgroundColor: Colors.orange[700],
      duration: const Duration(seconds: 3),
    ),
  );
  
  // 🚀 FIX: Reload current trip and cards
  await _loadCurrentPassengerTrip();
  await _loadUserNFCCards();
}
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.credit_card, color: Colors.blue[700]),
              title: const Text('My NFC Card'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showNFCCardsSheet();
              },
            ),
ListTile(
  leading: Icon(Icons.history, color: Colors.blue[700]),
  title: const Text('Trip History'),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TripHistoryPage()),
    );
  },
),
          ListTile(
            leading: Icon(Icons.person, color: Colors.blue[700]),
            title: const Text('Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNFCCardsSheet() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My NFC Cards',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadUserNFCCards,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingCards
                  ? const Center(child: CircularProgressIndicator())
                  : _userNFCCards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card_off, 
                                size: 64, 
                                color: Colors.grey[400]
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No NFC cards found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _userNFCCards.length,
                          itemBuilder: (context, index) {
                            final card = _userNFCCards[index];
                            return _buildNFCCardItem(card);
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildNFCCardItem(Map<String, dynamic> card) {
  final balance = (card['balance'] ?? 0.0).toDouble();
  final isActive = card['is_active'] ?? false;
  final isBlocked = card['is_blocked'] ?? false;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isActive && !isBlocked
            ? [Colors.blue[700]!, Colors.blue[500]!]
            : [Colors.grey[600]!, Colors.grey[400]!],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  card['card_type'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isBlocked
                    ? Colors.red[300]
                    : (isActive ? Colors.green[300] : Colors.orange[300]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isBlocked ? 'Blocked' : (isActive ? 'Active' : 'Inactive'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          card['card_number'] ?? 'N/A',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (card['discount_type'] != null && card['discount_type'] != 'none')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.discount, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      card['discount_type'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}


Future<void> _handleTapOut() async {
  if (_currentPassengerTrip == null) return;
  
  // Get current location
  Position position = await Geolocator.getCurrentPosition();
  
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  
  final trip = _currentPassengerTrip!['trips'];
  
  try {
    final result = await PassengerTapService.tapOut(
      passengerId: userId,
      nfcCardId: _currentPassengerTrip!['nfc_card_id'],
      tripId: _currentPassengerTrip!['trip_id'],
      busId: trip['buses']['id'],
      driverId: trip['drivers']['id'],
      latitude: position.latitude,
      longitude: position.longitude,
    );
    
if (result['success']) {
  final passengerCount = result['passenger_count'] ?? 1;
  final farePerPassenger = result['fare_per_passenger'] ?? result['fare'];
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Trip Complete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (passengerCount > 1) ...[
            Text(
              'Passengers: $passengerCount',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Fare per passenger: ₱${farePerPassenger.toStringAsFixed(2)}'),
            const Divider(height: 16),
          ],
          Text('Total Fare: ₱${result['fare'].toStringAsFixed(2)}'),
          Text('Distance: ${result['distance'].toStringAsFixed(2)} km'),
          Text('New Balance: ₱${result['new_balance'].toStringAsFixed(2)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  
  // Reload current trip
  await _loadCurrentPassengerTrip();
  await _loadUserNFCCards(); // Refresh card balance
}
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}