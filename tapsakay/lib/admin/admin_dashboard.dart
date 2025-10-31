import 'package:flutter/material.dart';
import 'package:tapsakay/admin/admin_buses_page.dart';
import 'package:tapsakay/admin/admin_drivers_page.dart';
import 'package:tapsakay/admin/admin_nfc_cards_page.dart';
import 'package:tapsakay/admin/admin_transactions_page.dart';
import 'package:tapsakay/admin/admin_trips_page.dart';
import 'package:tapsakay/admin/admin_users_page.dart';
import 'package:tapsakay/driver/driver_service.dart';
import '../user/login_api.dart';
import 'package:tapsakay/admin/admin_live_map_page.dart';
import '../services/bus_service.dart';
// Assuming this path

// --- Dark Theme Colors ---
const Color _darkSidebarColor = Color(0xFF1E293B);
const Color _darkSidebarTextColor = Color(0xFFF1F5F9); // Light text
const Color _darkSidebarIconColor = Color(0xFF94A3B8); // Light grey icon
const Color _darkAccentColor = Colors.cyanAccent;
const Color _darkSelectedTileColor = Color(0xFF2D3748); // Darker background for selected item
const Color _mainBackgroundColor = Color(0xFFF5F7FA);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _userName = '';
  bool _isLoading = true;

  // 🚀 NEW STATE VARIABLES FOR DYNAMIC DATA
  int _totalBuses = 0;
  int _activeDrivers = 0;
  int _totalPassengers = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // 🚀 NEW: Load dashboard statistics
    _loadDashboardData();
  }

  // 🚀 NEW METHOD TO LOAD ALL DASHBOARD DATA
  Future<void> _loadDashboardData() async {
    try {
      // 1. Get Driver and Passenger Stats (from DriverService)
      final driverStats = await DriverService.getDriverStatistics();

      // 2. Get Bus Stats (from BusService)
      final busStats = await BusService.getBusStatistics();

      setState(() {
        _activeDrivers = driverStats['active_drivers'] ?? 0;
        _totalPassengers = driverStats['total_passengers'] ?? 0;
        _totalBuses = busStats['total'] ?? 0;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      // Optionally show a snackbar error
    }
  }

  Future<void> _loadUserProfile() async {
    // ... (Your existing user profile loading logic)
    try {
      final profile = await LoginApi.getUserProfile();
      setState(() {
        _userName = profile?['full_name'] ?? 'Admin';
        if (_userName.isEmpty) _userName = 'Admin';
        _isLoading = false; // We only set loading to false here initially if data load takes longer
      });
    } catch (e) {
      setState(() {
        _userName = 'Admin';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    // ... (Your existing logout logic)
    try {
      await LoginApi.logout();
      if (mounted) {
        // AuthWrapper will handle navigation
      }
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

 Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $_userName! 👋',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B), // Dark text for light background
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your transport system efficiently',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Statistics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _StatCard(
                    title: 'Total Buses',
                    value: '$_totalBuses',
                    icon: Icons.directions_bus,
                    color: Colors.blue.shade700,
                    width: isDesktop ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _StatCard(
                    title: 'Active Drivers',
                    value: '$_activeDrivers',
                    icon: Icons.person_pin_circle_rounded,
                    color: Colors.green.shade700,
                    width: isDesktop ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                  _StatCard(
                    title: 'Total Passengers',
                    value: _totalPassengers.toString(),
                    icon: Icons.people_alt_rounded,
                    color: Colors.orange.shade700,
                    width: isDesktop ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _ActionCard(
                    title: 'Manage Buses',
                    description: 'Add, edit, or remove buses',
                    icon: Icons.directions_bus,
                    color: Colors.blue.shade700,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                    },
                    width: isDesktop ? (constraints.maxWidth - 48) / 2 : constraints.maxWidth,
                  ),
                  _ActionCard(
                    title: 'Manage Drivers',
                    description: 'Assign drivers and monitor activity',
                    icon: Icons.badge,
                    color: Colors.green.shade700,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                    },
                    width: isDesktop ? (constraints.maxWidth - 48) / 2 : constraints.maxWidth,
                  ),
                  _ActionCard(
                    title: 'View Transactions',
                    description: 'Monitor all fare transactions',
                    icon: Icons.receipt_long,
                    color: Colors.purple.shade700,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                    },
                    width: isDesktop ? (constraints.maxWidth - 48) / 2 : constraints.maxWidth,
                  ),
                  _ActionCard(
                    title: 'Manage Users',
                    description: 'View and manage all users',
                    icon: Icons.people,
                    color: Colors.orange.shade700,
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                    },
                    width: isDesktop ? (constraints.maxWidth - 48) / 2 : constraints.maxWidth,
                  ),
                  // 🎴 NEW: NFC Cards Quick Action
                  _ActionCard(
                    title: 'Manage NFC Cards',
                    description: 'Create and manage NFC cards',
                    icon: Icons.credit_card,
                    color: Colors.cyan.shade700,
                    onTap: () {
                      setState(() => _selectedIndex = 5);
                    },
                    width: isDesktop ? (constraints.maxWidth - 48) / 2 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildUserProfileBadge(bool showDetails) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.cyanAccent.shade700, // Use a bright color for contrast
            radius: 20,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Color(0xFF1E293B), // Dark text on light accent color
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (showDetails) const SizedBox(width: 12),
          if (showDetails)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkSidebarTextColor, // Light text for dark background
                  ),
                ),
                Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500], // Subtle indicator color
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

final List<Widget> pages = [
  _buildDashboardContent(),
  const AdminBusesPage(),
  const AdminDriversPage(),
  const AdminTransactionsPage(),  // ← NEW
  const AdminUsersPage(),
  const AdminNFCCardsPage(),
  const AdminLiveMapPage(),
  const AdminTripsPage(),  // ← ADD THIS NEW PAGE
];

    // Show loading indicator until user profile and initial data is loaded
    if (_isLoading && (_totalBuses == 0 && _activeDrivers == 0 && _totalPassengers == 0)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _mainBackgroundColor,
      body: Row(
        children: [
          // 🚀 Revamped Sidebar (Desktop only) - Dark Theme
          if (isDesktop)
            Container(
              width: 260,
              color: _darkSidebarColor, // Dark background
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // ➡️ MODIFIED: USER PROFILE BADGE REPLACES LOGO
                  _buildUserProfileBadge(true),
                  const SizedBox(height: 16), // Reduced height for tighter packing
                  // Menu Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        // Changed Icon: Icons.dashboard -> Icons.bar_chart_rounded
                        _buildNavItem(0, Icons.bar_chart_rounded, 'Dashboard'),
                        _buildNavItem(1, Icons.directions_bus, 'Buses'),
                        _buildNavItem(2, Icons.badge, 'Drivers'),
                        _buildNavItem(3, Icons.receipt_long, 'Transactions'),
                        _buildNavItem(4, Icons.people, 'Users'),
                        _buildNavItem(5, Icons.credit_card, 'NFC Cards'),
                        _buildNavItem(6, Icons.map, 'Live Map'),
                      ],
                    ),
                  ),
                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent), // Red accent for logout
                      title: const Text('Logout', style: TextStyle(color: _darkSidebarTextColor)),
                      onTap: _handleLogout,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)), // Subtle border
                      ),
                      tileColor: _darkSelectedTileColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // ➡️ MODIFIED HERE: Top App Bar is only built if it's NOT desktop
                if (!isDesktop)
                  Container(
                    height: 70,
                    color: Colors.white, // Keep light or use a subtle shade
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Show Menu Button on mobile
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu),
                            iconSize: 28,
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                        const Spacer(), // Pushes user profile to the right on mobile

                        // Show minimalist badge on mobile header
                        _buildUserProfileBadge(false),
                      ],
                    ),
                  ),
                // ⬅️ END MODIFICATION

                // Page Content
                Expanded(child: pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
      // 🚀 Revamped Mobile Drawer - Dark Theme (Unchanged)
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: _darkSidebarColor, // Dark theme for drawer
              child: Column(
                children: [
                  // ➡️ MODIFIED: Replaced DrawerHeader with a simple container and the User Profile Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 40, bottom: 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A), // Even darker header
                    ),
                    child: Center(
                      child: _buildUserProfileBadge(true), // Show details in the drawer header
                    ),
                  ),
                  // Remove the extra padding after the badge, as it's included in the badge widget
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _buildNavItem(0, Icons.bar_chart_rounded, 'Dashboard'),
                      _buildNavItem(1, Icons.directions_bus, 'Buses'),
                      _buildNavItem(2, Icons.badge, 'Drivers'),
                      _buildNavItem(3, Icons.receipt_long, 'Transactions'),
                      _buildNavItem(4, Icons.people, 'Users'),
                      _buildNavItem(5, Icons.credit_card, 'NFC Cards'), // ✅ Added this line
                      _buildNavItem(6, Icons.map, 'Live Map'),          // ✅ Updated index
                    ],
                  ),
                ),

                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Logout', style: TextStyle(color: _darkSidebarTextColor)),
                      onTap: _handleLogout,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      tileColor: _darkSelectedTileColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : null,
    );
  }

  // 🚀 Revamped Nav Item for Dark Sidebar
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? _darkAccentColor : _darkSidebarIconColor,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? _darkAccentColor : _darkSidebarTextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: _darkSelectedTileColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (MediaQuery.of(context).size.width <= 800) {
            Navigator.pop(context);
          }
        },
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Slightly darker, more prominent shadow
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30, // Slightly larger
                    fontWeight: FontWeight.w900,
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

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // Slightly darker, more prominent shadow
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, size: 20, color: color), // Changed icon for a clearer forward indication
          ],
        ),
      ),
    );
  }
}