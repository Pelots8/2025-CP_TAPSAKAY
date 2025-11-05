import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tapsakay/driver/driver_profile_page.dart';
import 'package:tapsakay/driver/driver_service.dart';
import 'package:tapsakay/driver/driver_trip_history_page.dart';
import 'package:tapsakay/passenger/passenger_tap_service.dart';
import 'dart:async';
import '../user/login_api.dart';
import '../services/trip_service.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final MapController _mapController = MapController();
  String _userName = '';
  String? _driverId;
  Map<String, dynamic>? _assignedBus;
  bool _isOnDuty = false;
  bool _isLoading = true;
  bool _isTogglingDuty = false;
  LatLng _currentLocation = const LatLng(6.9214, 122.0790);
  double _currentZoom = 15.0;
  StreamSubscription<Position>? _locationSubscription;
  Map<String, dynamic>? _currentTrip;
  RealtimeChannel? _tripChannel;
  List<Map<String, dynamic>> _pendingTapIns = [];
  RealtimeChannel? _passengerTripsChannel;
  

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _tripChannel?.unsubscribe();
    _passengerTripsChannel?.unsubscribe();
    super.dispose();
    
  }

 Future<void> _initializeDriver() async {
  try {
    // Get user profile
    final userProfile = await LoginApi.getUserProfile();
    final userId = userProfile?['id'];

    if (userId == null) {
      throw Exception('User ID not found');
    }

    // Get driver profile
    final driverProfile = await DriverService.getDriverProfile(userId);

    if (driverProfile == null) {
      // Driver record doesn't exist - show error message
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Driver Record Not Found'),
            content: const Text(
              'Your driver account has not been set up yet. Please contact the administrator to create your driver profile with your license information.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await LoginApi.logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 🚀 FIX: Load current trip BEFORE setting state
    final isOnDuty = driverProfile['is_on_duty'] ?? false;
    Map<String, dynamic>? currentTrip;
    
    if (isOnDuty) {
      currentTrip = await TripService.getCurrentTrip(driverProfile['id']);
      
      // 🚀 If driver is marked on duty but has no active trip, reset duty status
      if (currentTrip == null) {
        print('Driver marked on duty but no active trip found. Resetting...');
        await DriverService.setOnDutyStatus(
          driverId: driverProfile['id'],
          isOnDuty: false,
          currentTripId: null,
        );
        // Update local variable
        driverProfile['is_on_duty'] = false;
      }
    }

    setState(() {
      _userName = userProfile?['full_name'] ?? 'Driver';
      _driverId = driverProfile['id'];
      _assignedBus = driverProfile['buses'];
      _isOnDuty = driverProfile['is_on_duty'] ?? false;
      _currentTrip = currentTrip; // Set the loaded trip
      _isLoading = false;
    });

    // Get current location
    _getCurrentLocation();
    _startLocationTracking();
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading driver data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Future<void> _getCurrentLocation() async {
    final position = await DriverService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, _currentZoom);
    }
  }

  void _startLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = DriverService.getLocationStream().listen(
      (position) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });

          // Only update database when on duty
          if (_isOnDuty && _driverId != null) {
            DriverService.updateDriverLocation(
              driverId: _driverId!,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        }
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
  }

void _subscribeToCurrentTrip() {
  if (_currentTrip == null) return;
  
  _tripChannel?.unsubscribe();
  _passengerTripsChannel?.unsubscribe();
  
  // Subscribe to trip updates
  _tripChannel = Supabase.instance.client
    .channel('trip-${_currentTrip!['id']}')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trips',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: _currentTrip!['id'],
      ),
      callback: (payload) async {
        if (mounted && _currentTrip != null) {
          final updatedTrip = await TripService.getTripDetails(_currentTrip!['id']);
          if (updatedTrip != null && mounted) {
            setState(() {
              _currentTrip = updatedTrip;
            });
          }
        }
      },
    )
    .subscribe();

  // 🚀 NEW: Subscribe to passenger_trips changes
  _passengerTripsChannel = Supabase.instance.client
    .channel('passenger-trips-${_currentTrip!['id']}')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'passenger_trips',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trip_id',
        value: _currentTrip!['id'],
      ),
      callback: (payload) async {
        // Load pending tap-ins when new passenger taps in
        await _loadPendingTapIns();
      },
    )
    .subscribe();
  
  // Load initial pending tap-ins
  _loadPendingTapIns();
}

Future<void> _loadPendingTapIns() async {
  if (_currentTrip == null) return;
  
  try {
    final pending = await PassengerTapService.getPendingTapIns(_currentTrip!['id']);
    
    if (mounted) {
      setState(() {
        _pendingTapIns = pending;
      });
      
      // Show modal if there are pending tap-ins
      if (pending.isNotEmpty) {
        _showPendingTapInsModal();
      }
    }
  } catch (e) {
    print('Error loading pending tap-ins: $e');
  }
}

void _showPendingTapInsModal() {
  if (_pendingTapIns.isEmpty) return;
  
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people, color: Colors.orange[700], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm Boarding',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_pendingTapIns.length} passenger(s) waiting',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // List of pending passengers
            ..._pendingTapIns.map((passengerTrip) {
              final passenger = passengerTrip['users'];
              final nfcCard = passengerTrip['nfc_cards'];
              final tapInTime = DateTime.parse(passengerTrip['tap_in_time']);
              final timeAgo = DateTime.now().difference(tapInTime).inSeconds;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              passenger['full_name'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
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
                                passenger['full_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Card: ${nfcCard['card_number']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Balance: ₱${(nfcCard['balance'] ?? 0.0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${timeAgo}s ago',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'How many passengers?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Passenger count buttons
                    Wrap(
                      spacing: 8,
                      children: List.generate(5, (index) {
                        final count = index + 1;
                        return SizedBox(
                          width: 60,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _confirmPassengerCount(
                              passengerTrip['id'],
                              count,
                              setModalState,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    
                    // Reject button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _rejectTapIn(
                          passengerTrip['id'],
                          setModalState,
                        ),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text(
                          'Reject',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmPassengerCount(
  String passengerTripId,
  int count,
  StateSetter setModalState,
) async {
  if (count == 1) {
    // Single passenger - confirm immediately with default breakdown
    try {
      await PassengerTapService.confirmPassengerCount(
        passengerTripId: passengerTripId,
        passengerCount: 1,
        tripId: _currentTrip!['id'],
        passengerBreakdown: {'regular': 1, 'student': 0, 'senior': 0, 'pwd': 0},
      );
      
      // Remove from pending and close modal
      setModalState(() {
        _pendingTapIns.removeWhere((pt) => pt['id'] == passengerTripId);
      });
      setState(() {
        _pendingTapIns.removeWhere((pt) => pt['id'] == passengerTripId);
      });
      if (_pendingTapIns.isEmpty) Navigator.pop(context);
      
      // Reload trip
      final updatedTrip = await TripService.getTripDetails(_currentTrip!['id']);
      if (updatedTrip != null && mounted) {
        setState(() => _currentTrip = updatedTrip);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmed: 1 passenger'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  } else {
    // Multiple passengers - show breakdown modal
    Navigator.pop(context); // Close pending modal first
    _showPassengerBreakdownModal(passengerTripId, count);
  }
}

void _showPassengerBreakdownModal(String passengerTripId, int totalCount) {
  int regular = totalCount;
  int student = 0;
  int senior = 0;
  int pwd = 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        int remaining = totalCount - (regular + student + senior + pwd);
        
        return AlertDialog(
          title: Text('Passenger Breakdown ($totalCount passengers)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Remaining: $remaining',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: remaining == 0 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPassengerTypeRow('Regular', regular, (val) {
                  setDialogState(() => regular = val);
                }),
                _buildPassengerTypeRow('Student (20% off)', student, (val) {
                  setDialogState(() => student = val);
                }),
                _buildPassengerTypeRow('Senior (20% off)', senior, (val) {
                  setDialogState(() => senior = val);
                }),
                _buildPassengerTypeRow('PWD (20% off)', pwd, (val) {
                  setDialogState(() => pwd = val);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadPendingTapIns(); // Reload pending list
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: remaining == 0
                  ? () async {
                      Navigator.pop(context);
                      try {
                        await PassengerTapService.confirmPassengerCount(
                          passengerTripId: passengerTripId,
                          passengerCount: totalCount,
                          tripId: _currentTrip!['id'],
                          passengerBreakdown: {
                            'regular': regular,
                            'student': student,
                            'senior': senior,
                            'pwd': pwd,
                          },
                        );
                        
                        setState(() {
                          _pendingTapIns.removeWhere((pt) => pt['id'] == passengerTripId);
                        });
                        
                        final updatedTrip = await TripService.getTripDetails(_currentTrip!['id']);
                        if (updatedTrip != null && mounted) {
                          setState(() => _currentTrip = updatedTrip);
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Confirmed: $totalCount passengers'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: remaining == 0 ? Colors.blue[700] : Colors.grey,
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildPassengerTypeRow(String label, int value, Function(int) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          color: Colors.red,
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
          color: Colors.green,
        ),
      ],
    ),
  );
}

Future<void> _rejectTapIn(
  String passengerTripId,
  StateSetter setModalState,
) async {
  try {
    await PassengerTapService.rejectTapIn(
      passengerTripId: passengerTripId,
      tripId: _currentTrip!['id'],
    );
    
    // Remove from pending list
    setModalState(() {
      _pendingTapIns.removeWhere((pt) => pt['id'] == passengerTripId);
    });
    
    setState(() {
      _pendingTapIns.removeWhere((pt) => pt['id'] == passengerTripId);
    });
    
    // Close modal if no more pending
    if (_pendingTapIns.isEmpty) {
      Navigator.pop(context);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Boarding rejected'),
        backgroundColor: Colors.orange,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _toggleDutyStatus() async {
  if (_assignedBus == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No bus assigned. Please contact your administrator.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => _isTogglingDuty = true);

  final newStatus = !_isOnDuty;

  try {
    if (newStatus) {
      // Show getting location message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Going on duty - get current location
      final position = await DriverService.getCurrentPosition();
      if (position == null) {
        throw Exception('Could not get your location. Please enable location services.');
      }

      // 🚀 STEP 1: Start a trip FIRST
      final trip = await TripService.startTrip(
        busId: _assignedBus!['id'],
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: 'Start Location',
      );

      // 🚀 STEP 2: THEN set on duty status with trip ID
      await DriverService.setOnDutyStatus(
        driverId: _driverId!,
        isOnDuty: true,
        latitude: position.latitude,
        longitude: position.longitude,
        currentTripId: trip['id'], // Pass the trip ID
      );

      setState(() {
        _isOnDuty = true;
        _currentTrip = trip;
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isTogglingDuty = false;
      });

      _startLocationTracking();
      _subscribeToCurrentTrip();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are now on duty. Trip started!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Going off duty
      
      // 🚀 STEP 1: End the current trip if exists
      if (_currentTrip != null) {
        final position = await DriverService.getCurrentPosition();
        if (position != null) {
          await TripService.endTrip(
            tripId: _currentTrip!['id'],
            latitude: position.latitude,
            longitude: position.longitude,
            locationName: 'End Location',
          );
        }
      }

      // 🚀 STEP 2: THEN clear on-duty status and trip ID
      await DriverService.setOnDutyStatus(
        driverId: _driverId!,
        isOnDuty: false,
        currentTripId: null, // Clear the trip ID
      );

      _stopLocationTracking();

      setState(() {
        _isOnDuty = false;
        _currentTrip = null;
        _isTogglingDuty = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are now off duty. Trip ended!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    setState(() => _isTogglingDuty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _handleLogout() async {
    if (_isOnDuty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please go off duty before logging out'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentZoom = position.zoom;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tapsakay.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isOnDuty ? Colors.blue[700] : Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Status Bar
          Positioned(
            top: 0,
            left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 : 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  children: [
                    Row(
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
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'D',
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
                                _userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Driver',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                            color: _isOnDuty
                                ? Colors.green[50]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isOnDuty
                                      ? Colors.green[600]
                                      : Colors.grey[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnDuty ? 'On Duty' : 'Off Duty',
                                style: TextStyle(
                                  color: _isOnDuty
                                      ? Colors.green[700]
                                      : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
if (_currentTrip != null) ...[
  const SizedBox(height: 12),
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green[200]!),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Icon(Icons.people, color: Colors.green[700], size: 20),
            const SizedBox(height: 4),
            Text(
              '${_currentTrip!['total_passengers'] ?? 0}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Passengers',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[600],
              ),
            ),
          ],
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.green[200],
        ),
        Column(
          children: [
            Icon(Icons.attach_money, color: Colors.green[700], size: 20),
            const SizedBox(height: 4),
            Text(
              '₱${(_currentTrip!['total_fare_collected'] ?? 0.0).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Collected',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[600],
              ),
            ),
          ],
        ),
      ],
    ),
  ),
] else ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      // No bus assigned message
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Bus Assigned',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                Text(
                                  'Contact administrator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Button
          Positioned(
            bottom: 20,
            left: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 + 20 : 20,
            right: isDesktop ? (MediaQuery.of(context).size.width - maxWidth) / 2 + 20 : 20,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _assignedBus == null || _isTogglingDuty
                          ? null
                          : _toggleDutyStatus,
                      icon: _isTogglingDuty
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isOnDuty ? Icons.stop : Icons.play_arrow,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isTogglingDuty
                            ? 'Please wait...'
                            : (_isOnDuty ? 'End Duty' : 'Start Duty'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _assignedBus == null || _isTogglingDuty
                            ? Colors.grey[400]
                            : (_isOnDuty ? Colors.red[600] : Colors.green[600]),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Action Buttons
          Positioned(
            right: 16,
            bottom: 100,
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
                        _currentZoom = (_currentZoom + 1).clamp(1.0, 18.0);
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
                        _currentZoom = (_currentZoom - 1).clamp(1.0, 18.0);
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
                    onPressed: () {
                      _mapController.move(_currentLocation, _currentZoom);
                    },
                    child: Icon(Icons.my_location, color: Colors.blue[700], size: 28),
                  ),
                ),
              ],
            ),
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
            leading: Icon(Icons.history, color: Colors.blue[700]),
            title: const Text('Trip History'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DriverTripHistoryPage()),
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
      MaterialPageRoute(builder: (context) => const DriverProfilePage()),
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
}