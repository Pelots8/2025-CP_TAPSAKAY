import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapsakay/driver/driver_service.dart';
import 'dart:async';
import '../user/login_api.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
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

      setState(() {
        _userName = userProfile?['full_name'] ?? 'Driver';
        _driverId = driverProfile['id'];
        _assignedBus = driverProfile['buses'];
        _isOnDuty = driverProfile['is_on_duty'] ?? false;
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

        await DriverService.setOnDutyStatus(
          driverId: _driverId!,
          isOnDuty: true,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        setState(() {
          _isOnDuty = true;
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isTogglingDuty = false;
        });

        _startLocationTracking();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are now on duty. GPS tracking started.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Going off duty
        await DriverService.setOnDutyStatus(
          driverId: _driverId!,
          isOnDuty: false,
        );

        _stopLocationTracking();

        setState(() {
          _isOnDuty = false;
          _isTogglingDuty = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are now off duty'),
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
                    if (_assignedBus != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Bus info - READ ONLY, no interaction
                      Row(
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
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _assignedBus!['bus_number'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _assignedBus!['route_name'] ?? 'No route',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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