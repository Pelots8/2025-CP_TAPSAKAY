import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/bus_service.dart';

class AdminLiveMapPage extends StatefulWidget {
  const AdminLiveMapPage({super.key});

  @override
  State<AdminLiveMapPage> createState() => _AdminLiveMapPageState();
}

class _AdminLiveMapPageState extends State<AdminLiveMapPage> {
  final MapController _mapController = MapController();
  // Zamboanga City default coordinates
  LatLng _currentLocation = const LatLng(6.9214, 122.0790); 
  double _currentZoom = 13.0;
  List<Map<String, dynamic>> _activeBuses = [];
  bool _isLoadingBuses = true;
  RealtimeChannel? _busesChannel;
  Map<String, dynamic>? _selectedBus;
  
  // State variable for mobile bottom sheet

  @override
  void initState() {
    super.initState();
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

  void _centerOnBus(Map<String, dynamic> driver) {
    final lat = driver['current_latitude'];
    final lng = driver['current_longitude'];
    
    if (lat != null && lng != null) {
      final location = LatLng(lat.toDouble(), lng.toDouble());
      _mapController.move(location, 16.0);
      setState(() {
        _selectedBus = driver;
// Close bottom sheet when selecting a bus
      });
    }
  }

  // Desktop sidebar panel (unchanged)
  Widget _buildDesktopSidebar() {
    return Container(
      width: 320,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Active Buses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadActiveBuses,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBusListContent(),
          ),
        ],
      ),
    );
  }

  // Shared bus list content
  Widget _buildBusListContent() {
    if (_isLoadingBuses) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_activeBuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No active buses',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _activeBuses.length,
      itemBuilder: (context, index) {
        final driver = _activeBuses[index];
        final bus = driver['buses'] as Map<String, dynamic>?; 
        final driverUser = driver['users'] as Map<String, dynamic>?;
        final isSelected = _selectedBus?['id'] == driver['id'];
        
        if (bus == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.blue[700]! : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => _centerOnBus(driver),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: Colors.blue[700],
                      size: 24,
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bus['route_name'] ?? 'No route',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (driverUser != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Driver: ${driverUser['full_name']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.location_on,
                    color: Colors.green[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Mobile bottom sheet for bus list
  void _showBusListBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Active Buses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _loadActiveBuses();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List content
              Expanded(
                child: _buildBusListContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile header
  Widget _buildMobileHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.map, size: 22, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Bus Tracking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_activeBuses.length}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Desktop header (unchanged)
  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.map, size: 28, color: Colors.blue[700]),
          const SizedBox(width: 12),
          const Text(
            'Live Bus Tracking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(width: 8),
                Text(
                  '${_activeBuses.length} Active',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBusInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedBus!['buses']['bus_number'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedBus!['buses']['route_name'] ?? 'No route',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_selectedBus!['users'] != null)
                    Text(
                      'Driver: ${_selectedBus!['users']['full_name']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedBus = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    return FlutterMap(
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
            _currentLocation = position.center;
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tapsakay.app',
        ),
        
        MarkerLayer(
          markers: _activeBuses.map((driver) {
            final bus = driver['buses'];
            if (bus == null) return null;
            
            final lat = driver['current_latitude'];
            final lng = driver['current_longitude'];
            
            if (lat == null || lng == null) return null;
            
            final location = LatLng(lat.toDouble(), lng.toDouble());
            final isSelected = _selectedBus?['id'] == driver['id'];
            
            return Marker(
              point: location,
              width: isSelected ? 60 : 45,
              height: isSelected ? 60 : 45,
              child: GestureDetector(
                onTap: () => _centerOnBus(driver),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange[600] : Colors.blue[700],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: isSelected ? 28 : 24,
                  ),
                ),
              ),
            );
          }).whereType<Marker>().toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header - Different for mobile vs desktop
          isLargeScreen ? _buildDesktopHeader() : _buildMobileHeader(),

          // Map and Side Panel Area
          Expanded(
            child: Row(
              children: [
                // Desktop sidebar (unchanged)
                if (isLargeScreen) _buildDesktopSidebar(),

                // Map Area
                Expanded(
                  child: Stack(
                    children: [
                      _buildMapWidget(),

                      // Zoom Controls
                      Positioned(
                        right: 16,
                        bottom: isLargeScreen ? 16 : 100,
                        child: SafeArea(
                          child: Column(
                            children: [
                              FloatingActionButton.small(
                                heroTag: 'zoom_in',
                                onPressed: () {
                                  setState(() {
                                    _currentZoom = (_currentZoom + 1).clamp(1.0, 18.0);
                                  });
                                  _mapController.move(_mapController.camera.center, _currentZoom); 
                                },
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'zoom_out',
                                onPressed: () {
                                  setState(() {
                                    _currentZoom = (_currentZoom - 1).clamp(1.0, 18.0);
                                  });
                                  _mapController.move(_mapController.camera.center, _currentZoom); 
                                },
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.remove),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: 'reset_view',
                                onPressed: () {
                                  setState(() {
                                    _currentZoom = 13.0;
                                    _currentLocation = const LatLng(6.9214, 122.0790);
                                    _selectedBus = null;
                                  });
                                  _mapController.move(_currentLocation, _currentZoom);
                                },
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.center_focus_strong),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Selected Bus Info Card 
                      if (_selectedBus != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: isLargeScreen ? null : 16,
                          child: SafeArea(
                            child: isLargeScreen 
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: _buildSelectedBusInfoCard(),
                                )
                              : _buildSelectedBusInfoCard(),
                          ),
                        ),
                      
                      // Mobile: Floating Bus List Button
                      if (!isLargeScreen)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SafeArea(
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: _showBusListBottomSheet,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.directions_bus,
                                            color: Colors.blue[700],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Active Buses',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${_activeBuses.length} buses currently active',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_up,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
}