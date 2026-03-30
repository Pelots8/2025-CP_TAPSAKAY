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
  String? _trackingBusId; // Track which bus the passenger is following

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
    _subscribeToNFCCardUpdates();
  }

  RealtimeChannel? _passengerTripChannel;
  RealtimeChannel? _nfcCardChannel;

  @override
  void dispose() {
    _busesChannel?.unsubscribe();
    _passengerTripChannel?.unsubscribe();
    _nfcCardChannel?.unsubscribe();
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
      }
    } catch (e) {
      print('Error loading current trip: $e');
    }
  }

  void _subscribeToPassengerTripUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
  
    // Subscribe to ALL changes on passenger's trips (insert, update, delete)
    _passengerTripChannel = Supabase.instance.client
      .channel('passenger-trip-realtime-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'passenger_trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'passenger_id',
          value: userId,
        ),
        callback: (payload) async {
          print('=== REALTIME: passenger_trips changed ===');
          print('Event: ${payload.eventType}');
          
          // Reload current trip when any change happens
          await _loadCurrentPassengerTrip();
          
          if (!mounted) return;
          
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Handle different events
          if (payload.eventType == PostgresChangeEvent.insert) {
            // New tap-in created
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have boarded the bus!'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (payload.eventType == PostgresChangeEvent.update) {
            // Check if trip was completed (tap-out)
            if (oldRecord['status'] == 'ongoing' && newRecord['status'] == 'completed') {
              final fare = newRecord['fare_amount'] ?? 0.0;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Trip completed! Fare: ₱${double.tryParse(fare.toString())?.toStringAsFixed(2) ?? '0.00'}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              // Reload NFC cards to update balance
              await _loadUserNFCCards();
            }
            // Show notification if driver confirmed
            else if (newRecord['driver_confirmed'] == true && oldRecord['driver_confirmed'] != true) {
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
          }
        },
      )
      .subscribe();
  }
  
  void _subscribeToNFCCardUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    // Subscribe to NFC card balance updates
    _nfcCardChannel = Supabase.instance.client
      .channel('nfc-card-realtime-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'nfc_cards',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'owner_id',
          value: userId,
        ),
        callback: (payload) async {
          print('=== REALTIME: nfc_cards balance updated ===');
          // Reload NFC cards to update balance display
          await _loadUserNFCCards();
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

  void _showCardBalance() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My NFC Cards',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
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
                                Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No NFC cards registered',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Contact admin to register a card',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _userNFCCards.length,
                            itemBuilder: (context, index) {
                              final card = _userNFCCards[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.credit_card, color: Colors.blue[700]),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Card UID',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  card['uid']?.toString().substring(0, 8) ?? 'N/A',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Active',
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Current Balance',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              '₱${(card['balance'] ?? 0.0).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: (card['balance'] ?? 0.0) > 100
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _trackBus(String driverId) {
    final driver = _activeBuses.firstWhere((d) => d['id'] == driverId);
    final lat = driver['current_latitude'];
    final lng = driver['current_longitude'];
    
    if (lat != null && lng != null) {
      final busLocation = LatLng(lat.toDouble(), lng.toDouble());
      _mapController.move(busLocation, 16.0);
      setState(() {
        _trackingBusId = driverId;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking bus ${driver['buses']['bus_number']}'),
          action: SnackBarAction(
            label: 'Stop',
            onPressed: () {
              setState(() {
                _trackingBusId = null;
              });
            },
          ),
        ),
      );
    }
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
              minZoom: 1.0,
              maxZoom: 18.0,
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
                    // Card Balance - Large
                    GestureDetector(
                      onTap: () => _showCardBalance(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingCards
                                  ? '...'
                                  : _userNFCCards.isEmpty
                                      ? 'No card'
                                      : '₱${double.tryParse(_userNFCCards.first['balance'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Hello Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hello, $_userName!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Find your ride',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Menu Button
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.grey[800]),
                      onPressed: () => _showMenu(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                          
                          final distance = _calculateDistance(
                            LatLng(
                              driver['current_latitude'] ?? 0,
                              driver['current_longitude'] ?? 0,
                            ),
                          );
                          
                          return Container(
                            width: 280,
                            margin: const EdgeInsets.only(right: 12),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.directions_bus,
                                            color: Colors.blue[700],
                                            size: 24,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDistance(distance),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      bus['bus_number'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bus['plate_number'] ?? 'No plate',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TripHistoryPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Trip History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardBusSheet(Map<String, dynamic> driver) {
    final bus = driver['buses'];
    if (bus == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.green[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      'Bus is nearby - Tap to board',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 14,
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

  Widget _buildOnboardSheet() {
    if (_currentPassengerTrip == null) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently on board',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _currentPassengerTrip!['trips']['buses']['bus_number'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap out when you reach your destination',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Trip Duration',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_currentPassengerTrip!['created_at']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Fare Deducted',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₱${(_currentPassengerTrip!['fare'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
                  ],
      ),
    );
  }

  Future<void> _handleTapIn(Map<String, dynamic> driver) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Check if user has NFC cards
      if (_userNFCCards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No NFC card registered. Please contact admin.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Use first NFC card
      final card = _userNFCCards.first;
      
      // Check card balance
      final balance = card['balance'] ?? 0.0;
      if (balance < 10.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance. Please top up your card.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get active trip for the bus
      final trips = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('driver_id', driver['id'])
          .eq('status', 'active')
          .maybeSingle();
      
      if (trips == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active trip found for this bus.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Create passenger trip
      await PassengerTapService.tapIn(
        passengerId: userId,
        nfcCardId: card['id'],
        tripId: trips['id'],
        busId: driver['buses']['id'],
        driverId: driver['id'],
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully tapped in!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload current trip
      await _loadCurrentPassengerTrip();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to tap in: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleTapOut() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      if (_currentPassengerTrip == null) return;
      
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get trip info
      final trip = _currentPassengerTrip!['trips'];
      if (trip == null) return;
      
      // Get bus_id and driver_id from the trip, not passenger_trips
      final busId = trip['bus_id'] ?? '';
      final driverId = trip['driver_id'] ?? '';
      
      await PassengerTapService.tapOut(
        passengerId: userId,
        nfcCardId: _currentPassengerTrip!['nfc_card_id'],
        tripId: trip['id'],
        busId: busId,
        driverId: driverId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully tapped out!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload current trip
      await _loadCurrentPassengerTrip();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to tap out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBusInfo(Map<String, dynamic> driver) {
    final bus = driver['buses'];
    if (bus == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
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
                      Text(
                        bus['plate_number'] ?? 'No plate',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('Driver: ${driver['full_name'] ?? 'N/A'}'),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text('Contact: ${driver['phone_number'] ?? 'N/A'}'),
            ),
            const SizedBox(height: 16),
            if (_currentPassengerTrip == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleTapIn(driver);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Board This Bus',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (_trackingBusId == driver['id'])
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _trackingBusId = null;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Stop Tracking',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _trackBus(driver['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Track Bus',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Trip History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TripHistoryPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('My NFC Cards'),
              onTap: () {
                Navigator.pop(context);
                _showCardBalance();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
