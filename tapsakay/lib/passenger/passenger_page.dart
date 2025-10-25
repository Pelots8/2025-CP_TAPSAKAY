import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/login_api.dart';
import '../services/bus_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _getCurrentLocation();
    _loadActiveBuses();
    _subscribeToActiveBuses();
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
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

          // Bottom Sheet with Active Buses
          Positioned(
            bottom: 0,
            left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            child: Container(
    // ... rest stays the same
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
            ),
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


  void _showBusInfo(Map<String, dynamic> driver) {
    final bus = driver['buses'];
    if (bus == null) return;
    
    final driverUser = driver['users'];
    
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
      const SizedBox(height: 4), // Add spacing
      Text(
        bus['route_name'] ?? 'No route',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      if (driverUser != null) ...[
        const SizedBox(height: 4), // Add spacing
        Text(
          'Driver: ${driverUser['full_name']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
      const SizedBox(height: 6), // Add spacing before distance
      Row(
        children: [
          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            _formatDistance(_calculateDistance(
              LatLng(
                driver['current_latitude'].toDouble(),
                driver['current_longitude'].toDouble(),
              ),
            )),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showOnboardConfirmation(driver);
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
          ],
        ),
      ),
    );
  }

  

  void _showOnboardConfirmation(Map<String, dynamic> driver) {
    final bus = driver['buses'];
    if (bus == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Board Bus?'),
        content: Text(
          'Do you wish to board ${bus['bus_number']} (${bus['route_name']})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Boarding ${bus['bus_number']}...'),
                  backgroundColor: Colors.green,
                ),
              );
              // TODO: Implement actual boarding logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                // TODO: Navigate to NFC card page
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: Colors.blue[700]),
              title: const Text('Trip History'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to trip history page
              },
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.blue[700]),
              title: const Text('Profile'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile page
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
}