import 'package:flutter/material.dart';
import '../services/bus_service.dart';

// Import this file in your admin_dashboard.dart:
// import 'admin_buses_page.dart';

class AdminBusesPage extends StatefulWidget {
  const AdminBusesPage({super.key});

  @override
  State<AdminBusesPage> createState() => _AdminBusesPageState();
}

class _AdminBusesPageState extends State<AdminBusesPage> {
  List<Map<String, dynamic>> _buses = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() => _isLoading = true);
    try {
      final buses = await BusService.getAllBusesWithDrivers();
      setState(() {
        _buses = buses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load buses: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBuses {
    if (_searchQuery.isEmpty) return _buses;
    return _buses.where((bus) {
      final busNumber = bus['bus_number']?.toString().toLowerCase() ?? '';
      final plateNumber = bus['plate_number']?.toString().toLowerCase() ?? '';
      final routeName = bus['route_name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return busNumber.contains(query) ||
          plateNumber.contains(query) ||
          routeName.contains(query);
    }).toList();
  }

  void _showAddBusDialog() {
    showDialog(
      context: context,
      builder: (context) => _BusFormDialog(
        onSave: () {
          _loadBuses();
        },
      ),
    );
  }

  void _showEditBusDialog(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => _BusFormDialog(
        bus: bus,
        onSave: () {
          _loadBuses();
        },
      ),
    );
  }

  Future<void> _deleteBus(String busId, String busNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to delete bus $busNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BusService.deleteBus(busId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bus deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBuses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete bus: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  const Text(
                    'Bus Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddBusDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Bus',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      const Text(
                        'Bus Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddBusDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Add Bus',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by bus number, plate, or route...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBuses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_bus,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No buses found'
                                  : 'No buses match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isEmpty)
                              TextButton(
                                onPressed: _showAddBusDialog,
                                child: const Text('Add your first bus'),
                              ),
                          ],
                        ),
                      )
                    : isDesktop
                        ? _buildDesktopTable()
                        : _buildMobileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Bus Number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Plate Number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Route',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Driver Assigned',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Capacity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 100),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBuses.length,
              itemBuilder: (context, index) {
                final bus = _filteredBuses[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          bus['bus_number'] ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(bus['plate_number'] ?? 'N/A'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(bus['route_name'] ?? 'No route'),
                      ),
                      Expanded(
                        flex: 2,
                        child: bus['drivers'] != null && bus['drivers'].isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus['drivers'][0]['users']?['full_name'] ??
                                        'N/A',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              )
                            : Text(
                                'Unassigned',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(bus['capacity']?.toString() ?? '0'),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(bus['status'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            bus['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: _getStatusColor(bus['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue[700]),
                              onPressed: () => _showEditBusDialog(bus),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBus(
                                bus['id'],
                                bus['bus_number'] ?? 'Unknown',
                              ),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBuses.length,
      itemBuilder: (context, index) {
        final bus = _filteredBuses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.directions_bus,
                        color: Colors.blue[700],
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bus['plate_number'] ?? 'N/A',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
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
                        color:
                            _getStatusColor(bus['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        bus['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          color: _getStatusColor(bus['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bus['route_name'] ?? 'No route',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (bus['drivers'] as List?)?.isNotEmpty == true
                            ? bus['drivers'][0]['users']['full_name'] ??
                                'Unassigned'
                            : 'Unassigned',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: bus['drivers'] == null ||
                                  bus['drivers'].isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Capacity: ${bus['capacity'] ?? 0}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditBusDialog(bus),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteBus(
                        bus['id'],
                        bus['bus_number'] ?? 'Unknown',
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusFormDialog extends StatefulWidget {
  final Map<String, dynamic>? bus;
  final VoidCallback onSave;

  const _BusFormDialog({
    this.bus,
    required this.onSave,
  });

  @override
  State<_BusFormDialog> createState() => _BusFormDialogState();
}

class _BusFormDialogState extends State<_BusFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _busNumberController;
  late TextEditingController _plateNumberController;
  late TextEditingController _capacityController;
  late TextEditingController _routeNameController;
  late TextEditingController _routeDescriptionController;
  bool _isMaintenance = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _busNumberController =
        TextEditingController(text: widget.bus?['bus_number'] ?? '');
    _plateNumberController =
        TextEditingController(text: widget.bus?['plate_number'] ?? '');
    _capacityController =
        TextEditingController(text: widget.bus?['capacity']?.toString() ?? '');
    _routeNameController =
        TextEditingController(text: widget.bus?['route_name'] ?? '');
    _routeDescriptionController =
        TextEditingController(text: widget.bus?['route_description'] ?? '');
    _isMaintenance = widget.bus?['status'] == 'maintenance';
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _plateNumberController.dispose();
    _capacityController.dispose();
    _routeNameController.dispose();
    _routeDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (widget.bus == null) {
        // Create new bus (status defaults to inactive in BusService.createBus)
        await BusService.createBus(
          busNumber: _busNumberController.text.trim(),
          plateNumber: _plateNumberController.text.trim(),
          capacity: int.parse(_capacityController.text.trim()),
          routeName: _routeNameController.text.trim(),
          routeDescription: _routeDescriptionController.text.trim().isEmpty
              ? null
              : _routeDescriptionController.text.trim(),
        );
      } else {
        // Update existing bus
        await BusService.updateBus(
          busId: widget.bus!['id'],
          busNumber: _busNumberController.text.trim(),
          plateNumber: _plateNumberController.text.trim(),
          capacity: int.parse(_capacityController.text.trim()),
          routeName: _routeNameController.text.trim(),
          routeDescription: _routeDescriptionController.text.trim().isEmpty
              ? null
              : _routeDescriptionController.text.trim(),
          status: _isMaintenance ? 'maintenance' : 'inactive',
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.bus == null
                  ? 'Bus created successfully'
                  : 'Bus updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSave();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bus == null ? 'Add New Bus' : 'Edit Bus',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _busNumberController,
                  decoration: InputDecoration(
                    labelText: 'Bus Number',
                    hintText: 'e.g., BUS-001',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.directions_bus),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bus number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateNumberController,
                  decoration: InputDecoration(
                    labelText: 'Plate Number',
                    hintText: 'e.g., ABC-1234',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.confirmation_number),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Plate number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  decoration: InputDecoration(
                    labelText: 'Capacity',
                    hintText: 'e.g., 20',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Capacity is required';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    if (int.parse(value.trim()) <= 0) {
                      return 'Capacity must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _routeNameController,
                  decoration: InputDecoration(
                    labelText: 'Route Name',
                    hintText: 'e.g., Tetuan - Canelar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.route),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Route name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _routeDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Route Description (Optional)',
                    hintText: 'Describe the route...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                if (widget.bus != null) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Under Maintenance'),
                    value: _isMaintenance,
                    onChanged: (value) {
                      setState(() => _isMaintenance = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.bus == null ? 'Create' : 'Update',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}