import 'package:flutter/material.dart';
import 'package:tapsakay/admin/admin_driver_service.dart';
import 'package:intl/intl.dart';

class AdminDriversPage extends StatefulWidget {
  const AdminDriversPage({super.key});

  @override
  State<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends State<AdminDriversPage> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final drivers = await AdminDriverService.getAllDrivers();
      setState(() {
        _drivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load drivers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    if (_searchQuery.isEmpty) return _drivers;
    return _drivers.where((driver) {
      final name = driver['users']?['full_name']?.toString().toLowerCase() ?? '';
      final email = driver['users']?['email']?.toString().toLowerCase() ?? '';
      final license = driver['driver_license_number']?.toString().toLowerCase() ?? '';
      final busNumber = driver['buses']?['bus_number']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          license.contains(query) ||
          busNumber.contains(query);
    }).toList();
  }

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => _DriverFormDialog(
        onSave: () {
          _loadDrivers();
        },
      ),
    );
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => _DriverFormDialog(
        driver: driver,
        onSave: () {
          _loadDrivers();
        },
      ),
    );
  }

  Future<void> _deleteDriver(String driverId, String driverName, String? busId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Driver'),
        content: Text(
          'Are you sure you want to remove $driverName as a driver?\n\n'
          'This will convert their account back to a passenger.',
        ),
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
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminDriverService.deleteDriver(driverId, busId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDrivers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove driver: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getDutyStatusColor(bool? isOnDuty) {
    return isOnDuty == true ? Colors.green : Colors.grey;
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
  padding: const EdgeInsets.all(16), // Reduced from 24 for mobile
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title and Button - Stack them vertically on mobile
      if (!isDesktop) ...[
        const Text(
          'Driver Management',
          style: TextStyle(
            fontSize: 24, // Reduced from 28 for mobile
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showAddDriverDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Driver',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
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
              'Driver Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Driver',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
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
      // Search Bar (same for both)
      Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, license, or bus...',
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
                : _filteredDrivers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No drivers found'
                                  : 'No drivers match your search',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isEmpty)
                              TextButton(
                                onPressed: _showAddDriverDialog,
                                child: const Text('Add your first driver'),
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
          // Table Header
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
                    'Driver Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Contact',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'License Number',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Assigned Bus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Availability',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
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
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 100),
              ],
            ),
          ),
          // Table Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDrivers.length,
            itemBuilder: (context, index) {
              final driver = _filteredDrivers[index];
              final user = driver['users'];
              final bus = driver['buses'];
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
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Icon(
                              Icons.person,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user?['full_name'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?['email'] ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            user?['phone_number'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver['driver_license_number'] ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (driver['license_expiry_date'] != null)
                            Text(
                              'Exp: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(driver['license_expiry_date']))}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: bus != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bus['bus_number'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  bus['route_name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Not assigned',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          bus != null ? 'Assigned' : 'Available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: bus != null
                                ? Colors.blue[700]
                                : Colors.green[700],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          driver['is_on_duty'] == true ? 'ON DUTY' : 'OFF DUTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _getDutyStatusColor(driver['is_on_duty']),
                            fontSize: 11,
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
                            onPressed: () => _showEditDriverDialog(driver),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteDriver(
                              driver['id'],
                              user?['full_name'] ?? 'Unknown',
                              bus?['id'],
                            ),
                            tooltip: 'Remove',
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
      itemCount: _filteredDrivers.length,
      itemBuilder: (context, index) {
        final driver = _filteredDrivers[index];
        final user = driver['users'];
        final bus = driver['buses'];
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
                    CircleAvatar(
                      backgroundColor: Colors.green[100],
                      radius: 24,
                      child: Icon(
                        Icons.person,
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
                            user?['full_name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?['email'] ?? 'N/A',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
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
                        color: _getDutyStatusColor(driver['is_on_duty'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        driver['is_on_duty'] == true ? 'ON DUTY' : 'OFF',
                        style: TextStyle(
                          color: _getDutyStatusColor(driver['is_on_duty']),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.phone,
                  'Phone',
                  user?['phone_number'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.badge,
                  'License',
                  driver['driver_license_number'] ?? 'N/A',
                ),
                if (driver['license_expiry_date'] != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      'Expires: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(driver['license_expiry_date']))}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.directions_bus,
                  'Assigned Bus',
                  bus != null
                      ? '${bus['bus_number']} - ${bus['route_name']}'
                      : 'Not assigned',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDriverDialog(driver),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteDriver(
                        driver['id'],
                        user?['full_name'] ?? 'Unknown',
                        bus?['id'],
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Remove'),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverFormDialog extends StatefulWidget {
  final Map<String, dynamic>? driver;
  final VoidCallback onSave;

  const _DriverFormDialog({
    this.driver,
    required this.onSave,
  });

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _licenseNumberController;
  DateTime? _licenseExpiryDate;
  String? _selectedUserId;
  String? _selectedBusId;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _buses = [];
  bool _isLoadingUsers = true;
  bool _isLoadingBuses = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _licenseNumberController = TextEditingController(
      text: widget.driver?['driver_license_number'] ?? '',
    );
    
    if (widget.driver != null) {
      // Edit mode
      _selectedUserId = widget.driver!['id'];
      _selectedBusId = widget.driver!['assigned_bus_id'];
      if (widget.driver!['license_expiry_date'] != null) {
        _licenseExpiryDate = DateTime.parse(widget.driver!['license_expiry_date']);
      }
      _loadBusesForEdit();
    } else {
      // Add mode
      _loadPassengerUsers();
      _loadAvailableBuses();
    }
  }

  Future<void> _loadPassengerUsers() async {
    try {
      final users = await AdminDriverService.getPassengerUsers();
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAvailableBuses() async {
    try {
      final buses = await AdminDriverService.getAvailableBuses();
      setState(() {
        _buses = buses;
        _isLoadingBuses = false;
      });
    } catch (e) {
      setState(() => _isLoadingBuses = false);
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

  Future<void> _loadBusesForEdit() async {
    try {
      final buses = await AdminDriverService.getBusesForAssignment(_selectedBusId);
      setState(() {
        _buses = buses;
        _isLoadingBuses = false;
      });
    } catch (e) {
      setState(() => _isLoadingBuses = false);
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _licenseExpiryDate = picked);
    }
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_licenseExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select license expiry date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.driver == null && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.driver == null) {
        // Create new driver
        await AdminDriverService.createDriver(
          userId: _selectedUserId!,
          licenseNumber: _licenseNumberController.text.trim(),
          licenseExpiryDate: _licenseExpiryDate!,
          assignedBusId: _selectedBusId,
        );
      } else {
        // Update existing driver
        await AdminDriverService.updateDriver(
          driverId: widget.driver!['id'],
          licenseNumber: _licenseNumberController.text.trim(),
          licenseExpiryDate: _licenseExpiryDate!,
          assignedBusId: _selectedBusId,
          previousBusId: widget.driver!['assigned_bus_id'],
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.driver == null
                  ? 'Driver added successfully'
                  : 'Driver updated successfully',
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
  final bool isEditMode = widget.driver != null;
  
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
              Row(
                children: [
                  Icon(Icons.badge, color: Colors.green[700], size: 32),
                  const SizedBox(width: 12),
                  Text(
                    isEditMode ? 'Edit Driver' : 'Add New Driver',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // User Selection (only in add mode)
              if (!isEditMode) ...[
                Text(
                  'Select User Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingUsers
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : _users.isEmpty
                        ? Container(
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
                                    'No passenger accounts available. Users must sign up first.',
                                    style: TextStyle(color: Colors.orange[900]),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedUserId,
                            decoration: InputDecoration(
                              labelText: 'Select User',
                              hintText: 'Choose a passenger account',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            isExpanded: true,
                            menuMaxHeight: 300,
                            items: _users.map<DropdownMenuItem<String>>((user) {
                              return DropdownMenuItem<String>(
                                value: user['id'],
                                child: Text(
                                  '${user['full_name']} (${user['email']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedUserId = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a user';
                              }
                              return null;
                            },
                          ),
                const SizedBox(height: 16),
              ] else ...[
                // Show driver info in edit mode
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.person, color: Colors.green[700]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driver!['users']?['full_name'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.driver!['users']?['email'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // License Number
              TextFormField(
                controller: _licenseNumberController,
                decoration: InputDecoration(
                  labelText: 'Driver License Number',
                  hintText: 'e.g., DL-2024-001',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'License number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // License Expiry Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'License Expiry Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _licenseExpiryDate == null
                        ? 'Select date'
                        : DateFormat('MMMM dd, yyyy').format(_licenseExpiryDate!),
                    style: TextStyle(
                      color: _licenseExpiryDate == null
                          ? Colors.grey[600]
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bus Assignment
              Text(
                'Bus Assignment (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingBuses
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButtonFormField<String>(
                    value: _buses.any((bus) => bus['id'] == _selectedBusId) ? _selectedBusId : null,
                    decoration: InputDecoration(
                      labelText: 'Assign Bus',
                      hintText: 'Optional - Select a bus',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.directions_bus),
                    ),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No bus assigned'),
                      ),
                      ..._buses.map<DropdownMenuItem<String>>((bus) {
                        return DropdownMenuItem<String>(
                          value: bus['id'],
                          child: Text(
                            '${bus['bus_number']} - ${bus['route_name'] ?? 'No route'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedBusId = value);
                    },
                  )
                  ,
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
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
                            isEditMode ? 'Update Driver' : 'Add Driver',
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