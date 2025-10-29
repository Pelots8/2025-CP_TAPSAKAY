import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/trip_service.dart';

class AdminTripsPage extends StatefulWidget {
  const AdminTripsPage({super.key});

  @override
  State<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends State<AdminTripsPage> {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  String? _selectedStatus;
  RealtimeChannel? _tripsChannel;
  
  Map<String, dynamic> _statistics = {
    'total_trips': 0,
    'ongoing_trips': 0,
    'completed_trips': 0,
    'total_revenue': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _loadStatistics();
    _subscribeToTrips();
  }

  @override
  void dispose() {
    _tripsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    try {
      setState(() => _isLoading = true);
      final trips = await TripService.getAllTrips(status: _selectedStatus);
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trips: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await TripService.getTripStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _subscribeToTrips() {
    _tripsChannel = TripService.subscribeToTrips(
      onUpdate: (trips) {
        if (mounted) {
          setState(() {
            _trips = trips;
          });
          _loadStatistics();
        }
      },
      status: _selectedStatus,
    );
  }

  void _filterByStatus(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _tripsChannel?.unsubscribe();
    _loadTrips();
    _subscribeToTrips();
  }

  String _formatCurrency(dynamic value) {
    final amount = (value ?? 0.0).toDouble();
    return '₱${amount.toStringAsFixed(2)}';
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDuration(String? startTime, String? endTime) {
    if (startTime == null) return 'N/A';
    try {
      final start = DateTime.parse(startTime);
      final end = endTime != null ? DateTime.parse(endTime) : DateTime.now();
      final duration = end.difference(start);
      
      if (duration.inHours > 0) {
        return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
      } else {
        return '${duration.inMinutes}m';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ongoing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'ongoing':
        return Icons.directions_bus;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showTripDetails(Map<String, dynamic> trip) async {
    // Load detailed trip information
    final tripDetails = await TripService.getTripDetails(trip['id']);
    
    if (!mounted || tripDetails == null) return;

    showDialog(
      context: context,
      builder: (context) => _TripDetailsDialog(
        trip: tripDetails,
        formatCurrency: _formatCurrency,
        formatDateTime: _formatDateTime,
        formatDuration: _formatDuration,
        getStatusColor: _getStatusColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header with Statistics
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Trips',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _loadTrips();
                        _loadStatistics();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Statistics Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 800;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          title: 'Total Trips',
                          value: '${_statistics['total_trips']}',
                          icon: Icons.route,
                          color: Colors.blue.shade700,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _StatCard(
                          title: 'Ongoing',
                          value: '${_statistics['ongoing_trips']}',
                          icon: Icons.directions_bus,
                          color: Colors.orange.shade700,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _StatCard(
                          title: 'Completed',
                          value: '${_statistics['completed_trips']}',
                          icon: Icons.check_circle,
                          color: Colors.green.shade700,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                        _StatCard(
                          title: 'Revenue',
                          value: _formatCurrency(_statistics['total_revenue']),
                          icon: Icons.attach_money,
                          color: Colors.purple.shade700,
                          width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Filter Chips
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedStatus == null,
                      onSelected: (selected) => _filterByStatus(null),
                    ),
                    FilterChip(
                      label: const Text('Ongoing'),
                      selected: _selectedStatus == 'ongoing',
                      onSelected: (selected) => _filterByStatus('ongoing'),
                    ),
                    FilterChip(
                      label: const Text('Completed'),
                      selected: _selectedStatus == 'completed',
                      onSelected: (selected) => _filterByStatus('completed'),
                    ),
                    FilterChip(
                      label: const Text('Cancelled'),
                      selected: _selectedStatus == 'cancelled',
                      onSelected: (selected) => _filterByStatus('cancelled'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Trips List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.route, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No trips found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) {
                          final trip = _trips[index];
                          return _TripCard(
                            trip: trip,
                            formatCurrency: _formatCurrency,
                            formatDateTime: _formatDateTime,
                            formatDuration: _formatDuration,
                            getStatusColor: _getStatusColor,
                            getStatusIcon: _getStatusIcon,
                            onTap: () => _showTripDetails(trip),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
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

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String Function(dynamic) formatCurrency;
  final String Function(String?) formatDateTime;
  final String Function(String?, String?) formatDuration;
  final Color Function(String?) getStatusColor;
  final IconData Function(String?) getStatusIcon;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.formatCurrency,
    required this.formatDateTime,
    required this.formatDuration,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bus = trip['buses'];
    final driver = trip['drivers'];
    final driverUser = driver?['users'];
    final status = trip['status'];

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getStatusIcon(status),
                    color: getStatusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus?['bus_number'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        bus?['route_name'] ?? 'No route',
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
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status?.toUpperCase() ?? 'N/A',
                    style: TextStyle(
                      color: getStatusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    icon: Icons.person,
                    label: 'Driver',
                    value: driverUser?['full_name'] ?? 'N/A',
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    icon: Icons.access_time,
                    label: 'Duration',
                    value: formatDuration(trip['start_time'], trip['end_time']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    icon: Icons.people,
                    label: 'Passengers',
                    value: '${trip['total_passengers'] ?? 0}',
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    icon: Icons.attach_money,
                    label: 'Fare Collected',
                    value: formatCurrency(trip['total_fare_collected']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Started: ${formatDateTime(trip['start_time'])}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (trip['end_time'] != null)
              Text(
                'Ended: ${formatDateTime(trip['end_time'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String Function(dynamic) formatCurrency;
  final String Function(String?) formatDateTime;
  final String Function(String?, String?) formatDuration;
  final Color Function(String?) getStatusColor;

  const _TripDetailsDialog({
    required this.trip,
    required this.formatCurrency,
    required this.formatDateTime,
    required this.formatDuration,
    required this.getStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final bus = trip['buses'];
    final driver = trip['drivers'];
    final driverUser = driver?['users'];
    final passengerTrips = trip['passenger_trips'] as List? ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Trip Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Bus', bus?['bus_number'] ?? 'N/A'),
                    _DetailRow('Route', bus?['route_name'] ?? 'N/A'),
                    _DetailRow('Driver', driverUser?['full_name'] ?? 'N/A'),
                    _DetailRow('Status', trip['status']?.toUpperCase() ?? 'N/A'),
                    _DetailRow('Start Time', formatDateTime(trip['start_time'])),
                    if (trip['end_time'] != null)
                      _DetailRow('End Time', formatDateTime(trip['end_time'])),
                    _DetailRow('Duration', formatDuration(trip['start_time'], trip['end_time'])),
                    _DetailRow('Total Passengers', '${trip['total_passengers'] ?? 0}'),
                    _DetailRow('Total Fare', formatCurrency(trip['total_fare_collected'])),
                    
                    const SizedBox(height: 24),
                    const Text(
                      'Passengers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (passengerTrips.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No passengers yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ...passengerTrips.map((pt) {
                        final passenger = pt['users'];
                        final card = pt['nfc_cards'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                passenger?['full_name'] ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Card: ${card?['card_number'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Fare: ${formatCurrency(pt['final_amount'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}