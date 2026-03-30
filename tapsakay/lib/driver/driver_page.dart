import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/driver_service.dart';
import '../services/trip_service.dart';
import '../services/passenger_tap_service.dart';
import '../services/nfc_service.dart';
import '../services/hardware_nfc_service.dart';
import '../user/login_api.dart';
import '../widgets/hardware_status_widget.dart';
import 'driver_profile_page.dart';
import 'package:geolocator/geolocator.dart';

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
  List<Map<String, dynamic>> _pendingTapIns = [];
  bool _isReadingNFC = false;
  RealtimeChannel? _passengerTripChannel;

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _passengerTripChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeDriver() async {
    try {
      final userProfile = await LoginApi.getUserProfile();
      final userId = userProfile?['id'];
      if (userId == null) throw Exception('User ID not found');
      final driverProfile = await DriverService.getDriverProfile(userId);
      if (driverProfile == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Driver Record Not Found'),
              content: const Text('Please contact admin to set up your driver profile.'),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await LoginApi.logout();
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        }
        return;
      }
      final isOnDuty = driverProfile['is_on_duty'] ?? false;
      Map<String, dynamic>? currentTrip;
      if (isOnDuty) {
        currentTrip = await TripService.getCurrentTrip(driverProfile['id']);
        if (currentTrip == null) {
          await DriverService.setOnDutyStatus(driverId: driverProfile['id'], isOnDuty: false, currentTripId: null);
          driverProfile['is_on_duty'] = false;
        }
      }
      setState(() {
        _userName = userProfile?['full_name'] ?? 'Driver';
        _driverId = driverProfile['id'];
        _assignedBus = driverProfile['buses'];
        _isOnDuty = driverProfile['is_on_duty'] ?? false;
        _currentTrip = currentTrip;
        _isLoading = false;
      });
      _getCurrentLocation();
      _startLocationTracking();
      if (_isOnDuty && _currentTrip != null) {
        await _loadPendingTapIns(); // Load existing tap-ins if already on duty
        _subscribeToPassengerTripUpdates(); // Subscribe to realtime updates
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await DriverService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
      _mapController.move(_currentLocation, _currentZoom);
    }
  }

  void _startLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = DriverService.getLocationStream().listen(
      (position) {
        if (mounted) {
          setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
          if (_isOnDuty && _driverId != null) {
            DriverService.updateDriverLocation(driverId: _driverId!, latitude: position.latitude, longitude: position.longitude);
          }
        }
      },
      onError: (error) => debugPrint('Location error: $error'),
    );
  }

  Future<void> _loadPendingTapIns() async {
    if (_currentTrip == null) return;
    try {
      final response = await Supabase.instance.client
          .from('passenger_trips')
          .select('*, users:passenger_id(full_name)')
          .eq('trip_id', _currentTrip!['id'])
          .eq('status', 'ongoing');
      
      setState(() {
        _pendingTapIns = (response as List).map((trip) => {
          'nfc_card_id': trip['nfc_card_id'],
          'passenger_id': trip['passenger_id'],
          'passenger_name': trip['users']?['full_name'] ?? 'Unknown',
          'tap_in_time': DateTime.parse(trip['tap_in_time']),
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading pending tap-ins: $e');
    }
  }
  
  void _subscribeToPassengerTripUpdates() {
    if (_currentTrip == null) return;
    
    // Unsubscribe from previous channel if exists
    _passengerTripChannel?.unsubscribe();
    
    // Subscribe to ALL changes on this trip's passenger_trips
    _passengerTripChannel = Supabase.instance.client
      .channel('driver-passenger-trips-${_currentTrip!['id']}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'passenger_trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: _currentTrip!['id'],
        ),
        callback: (payload) async {
          print('=== DRIVER REALTIME: passenger_trips changed ===');
          print('Event: ${payload.eventType}');
          
          // Reload passenger list
          await _loadPendingTapIns();
          
          if (!mounted) return;
          
          final newRecord = payload.newRecord;
          
          // Show notifications based on event type
          if (payload.eventType == PostgresChangeEvent.insert) {
            // New passenger tapped in
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New passenger boarded! (${_pendingTapIns.length} total)'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (payload.eventType == PostgresChangeEvent.update) {
            // Check if passenger tapped out
            if (newRecord['status'] == 'completed') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Passenger alighted. (${_pendingTapIns.length} remaining)'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      )
      .subscribe();
  }

  Future<void> _toggleDutyStatus() async {
    if (_assignedBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bus assigned.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isTogglingDuty = true);
    final newStatus = !_isOnDuty;
    try {
      if (newStatus) {
        final position = await DriverService.getCurrentPosition();
        if (position == null) throw Exception('Could not get location.');
        final trip = await TripService.startTrip(
          busId: _assignedBus!['id'],
          driverId: _driverId!,
          latitude: position.latitude,
          longitude: position.longitude,
          locationName: 'Start Location',
        );
        await DriverService.setOnDutyStatus(
          driverId: _driverId!,
          isOnDuty: true,
          latitude: position.latitude,
          longitude: position.longitude,
          currentTripId: trip['id'],
        );
        setState(() {
          _isOnDuty = true;
          _currentTrip = trip;
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isTogglingDuty = false;
        });
        _startLocationTracking();
        await _loadPendingTapIns(); // Load existing tap-ins from database
        _subscribeToPassengerTripUpdates(); // Subscribe to realtime updates
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('On duty!'), backgroundColor: Colors.green));
      } else {
        if (_currentTrip != null) {
          final position = await DriverService.getCurrentPosition();
          if (position != null) {
            await TripService.endTrip(tripId: _currentTrip!['id'], latitude: position.latitude, longitude: position.longitude, locationName: 'End');
          }
        }
        await DriverService.setOnDutyStatus(driverId: _driverId!, isOnDuty: false, currentTripId: null);
        _locationSubscription?.cancel();
        _passengerTripChannel?.unsubscribe(); // Unsubscribe from realtime updates
        setState(() { _isOnDuty = false; _currentTrip = null; _pendingTapIns = []; _isTogglingDuty = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Off duty!'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      setState(() => _isTogglingDuty = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _readNFCForTapIn() async {
    if (!_isOnDuty || _currentTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be on duty'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isReadingNFC = true);
    try {
      // Use hardware PN532 NFC module instead of phone NFC
      final hardwareNfc = HardwareNFCService();
      final uid = await hardwareNfc.readCard(timeout: const Duration(seconds: 10));
      if (uid == null) throw Exception('No NFC card detected. Please tap card on the PN532 reader.');
      final cardInfo = await hardwareNfc.getCardInfo(uid);
      if (cardInfo == null) throw Exception('Card not registered in system');

      // Check if already tapped in
      final existingTapIn = _pendingTapIns.firstWhere(
        (tap) => tap['nfc_card_id'] == cardInfo['id'],
        orElse: () => {},
      );

      if (existingTapIn.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cardInfo['users']['full_name']} is already tapped in!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check card balance
      final balance = cardInfo['balance'] ?? 0.0;
      if (balance < 10.0) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Insufficient Balance'),
            content: Text('${cardInfo['users']['full_name']} has insufficient balance (₱${balance.toStringAsFixed(2)}).'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final position = await DriverService.getCurrentPosition();
      if (position == null) throw Exception('Cannot get location');

      await PassengerTapService.tapIn(
        passengerId: cardInfo['owner_id'],
        nfcCardId: cardInfo['id'],
        tripId: _currentTrip!['id'],
        busId: _assignedBus!['id'],
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _pendingTapIns.add({
          'nfc_card_id': cardInfo['id'],
          'passenger_id': cardInfo['owner_id'],
          'passenger_name': cardInfo['users']['full_name'],
          'tap_in_time': DateTime.now(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cardInfo['users']['full_name']} tapped in!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isReadingNFC = false);
    }
  }

  Future<void> _readNFCForTapOut() async {
    if (!_isOnDuty || _currentTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be on duty'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isReadingNFC = true);
    try {
      // Use hardware PN532 NFC module instead of phone NFC
      final hardwareNfc = HardwareNFCService();
      final uid = await hardwareNfc.readCard(timeout: const Duration(seconds: 10));
      if (uid == null) throw Exception('No NFC card detected. Please tap card on the PN532 reader.');
      final cardInfo = await hardwareNfc.getCardInfo(uid);
      if (cardInfo == null) throw Exception('Card not registered in system');

      // Check if tapped in
      final existingTapIn = _pendingTapIns.firstWhere(
        (tap) => tap['nfc_card_id'] == cardInfo['id'],
        orElse: () => {},
      );

      if (existingTapIn.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cardInfo['users']['full_name']} has not tapped in!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final position = await DriverService.getCurrentPosition();
      if (position == null) throw Exception('Cannot get location');

      await PassengerTapService.tapOut(
        passengerId: cardInfo['owner_id'],
        nfcCardId: cardInfo['id'],
        tripId: _currentTrip!['id'],
        busId: _assignedBus!['id'],
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _pendingTapIns.removeWhere((tap) => tap['nfc_card_id'] == cardInfo['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cardInfo['users']['full_name']} tapped out! Fare deducted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isReadingNFC = false);
    }
  }

  Future<void> _readNFCCard() async {
    if (!_isOnDuty || _currentTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be on duty'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isReadingNFC = true);
    try {
      // Use hardware PN532 NFC module instead of phone NFC
      final hardwareNfc = HardwareNFCService();
      final uid = await hardwareNfc.readCard(timeout: const Duration(seconds: 10));
      if (uid == null) throw Exception('No NFC card detected. Please tap card on the PN532 reader.');
      final cardInfo = await hardwareNfc.getCardInfo(uid);
      if (cardInfo == null) throw Exception('Card not registered in system');

      // Check if this card is already tapped in
      final existingTapIn = _pendingTapIns.firstWhere(
        (tap) => tap['nfc_card_id'] == cardInfo['id'],
        orElse: () => {},
      );

      if (existingTapIn.isNotEmpty) {
        // This is a TAP OUT - complete the trip
        final position = await DriverService.getCurrentPosition();
        if (position == null) throw Exception('Cannot get location');

        await PassengerTapService.tapOut(
          passengerId: cardInfo['owner_id'],
          nfcCardId: cardInfo['id'],
          tripId: _currentTrip!['id'],
          busId: _assignedBus!['id'],
          driverId: _driverId!,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        setState(() {
          _pendingTapIns.removeWhere((tap) => tap['nfc_card_id'] == cardInfo['id']);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cardInfo['users']['full_name']} tapped out! Fare deducted.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // This is a TAP IN - create trip record
        final position = await DriverService.getCurrentPosition();
        if (position == null) throw Exception('Cannot get location');

        // Check card balance
        final balance = cardInfo['balance'] ?? 0.0;
        if (balance < 10.0) { // Minimum fare check
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Insufficient Balance'),
              content: Text('${cardInfo['users']['full_name']} has insufficient balance (₱${balance.toStringAsFixed(2)}).'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        await PassengerTapService.tapIn(
          passengerId: cardInfo['owner_id'],
          nfcCardId: cardInfo['id'],
          tripId: _currentTrip!['id'],
          busId: _assignedBus!['id'],
          driverId: _driverId!,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        setState(() {
          _pendingTapIns.add({
            'nfc_card_id': cardInfo['id'],
            'passenger_name': cardInfo['users']['full_name'],
            'tap_in_time': DateTime.now(),
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cardInfo['users']['full_name']} tapped in!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isReadingNFC = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.blue[700],
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Welcome, $_userName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                          Text(_assignedBus != null ? 'Bus: ${_assignedBus!['plate_number']}' : 'No bus', style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                        ]),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DriverProfilePage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTogglingDuty ? null : _toggleDutyStatus,
                      icon: _isTogglingDuty ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_isOnDuty ? Icons.work_off : Icons.work),
                      label: Text(_isOnDuty ? 'Go Off Duty' : 'Go On Duty'),
                      style: ElevatedButton.styleFrom(backgroundColor: _isOnDuty ? Colors.red : Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const HardwareStatusWidget(),
                Expanded(
                  child: Stack(
                    children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _currentLocation, initialZoom: _currentZoom, minZoom: 10, maxZoom: 18),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.tapsakay'),
                    MarkerLayer(markers: [
                      Marker(point: _currentLocation, width: 40, height: 40, child: Container(
                        decoration: BoxDecoration(color: Colors.blue[700], shape: BoxShape.circle),
                        child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                      )),
                    ]),
                  ],
                ),
                if (_isOnDuty)
                  Positioned(
                    bottom: 80, right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.extended(
                          heroTag: 'tapIn',
                          onPressed: _isReadingNFC ? null : _readNFCForTapIn,
                          icon: _isReadingNFC ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
                          label: const Text('Tap In'),
                          backgroundColor: Colors.green[600],
                        ),
                        const SizedBox(height: 12),
                        FloatingActionButton.extended(
                          heroTag: 'tapOut',
                          onPressed: _isReadingNFC ? null : _readNFCForTapOut,
                          icon: _isReadingNFC ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.logout),
                          label: const Text('Tap Out'),
                          backgroundColor: Colors.orange[600],
                        ),
                      ],
                    ),
                  ),
                if (_isOnDuty)
                  Positioned(
                    bottom: 80, left: 20,
                    child: FloatingActionButton.extended(
                      heroTag: 'passengers',
                      onPressed: _showPassengerList,
                      icon: const Icon(Icons.people),
                      label: Text('${_pendingTapIns.length} Passengers'),
                      backgroundColor: _pendingTapIns.isEmpty ? Colors.grey[600] : Colors.blue[600],
                    ),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPassengerList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Passengers On Board (${_pendingTapIns.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Passenger list
            Expanded(
              child: _pendingTapIns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No passengers yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingTapIns.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final passenger = _pendingTapIns[index];
                        final tapInTime = passenger['tap_in_time'] as DateTime;
                        final duration = DateTime.now().difference(tapInTime);
                        final durationText = duration.inMinutes > 0
                            ? '${duration.inMinutes} min ago'
                            : '${duration.inSeconds} sec ago';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Text(
                              passenger['passenger_name']?.toString().substring(0, 1).toUpperCase() ?? 'P',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            passenger['passenger_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Tapped in $durationText'),
                          trailing: IconButton(
                            icon: Icon(Icons.logout, color: Colors.orange[700]),
                            onPressed: () {
                              Navigator.pop(context);
                              _tapOutPassenger(passenger);
                            },
                            tooltip: 'Tap Out',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tapOutPassenger(Map<String, dynamic> passenger) async {
    try {
      final position = await DriverService.getCurrentPosition();
      if (position == null) throw Exception('Cannot get location');

      // Find the card info for this passenger (using database lookup, no NFC read needed)
      final cardInfo = await Supabase.instance.client
          .from('nfc_cards')
          .select('*, users!owner_id(full_name, email)')
          .eq('id', passenger['nfc_card_id'])
          .maybeSingle();
      if (cardInfo == null) throw Exception('Card not found');

      await PassengerTapService.tapOut(
        passengerId: cardInfo['owner_id'],
        nfcCardId: passenger['nfc_card_id'],
        tripId: _currentTrip!['id'],
        busId: _assignedBus!['id'],
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _pendingTapIns.removeWhere((tap) => tap['nfc_card_id'] == passenger['nfc_card_id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${passenger['passenger_name']} tapped out! Fare deducted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }
}
