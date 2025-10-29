import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadUsers();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        _currentUserId = user?.id;
      });
    } catch (e) {
      print('Error getting current user ID: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await UserService.getUsers(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        roleFilter: _selectedRoleFilter,
      );
      setState(() {
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadUsers();
  }

  void _handleRoleFilterChange(String? value) {
    if (value != null) {
      setState(() {
        _selectedRoleFilter = value;
      });
      _loadUsers();
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    if (user['id'] == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool newStatus = !(user['is_active'] ?? true);
    try {
      await UserService.updateUserStatus(user['id'], newStatus);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${newStatus ? "activated" : "deactivated"} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (user['id'] == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Are you sure you want to deactivate ${user['full_name']}? '
          'They will no longer be able to access the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserService.deleteUser(user['id']);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deactivated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deactivating user: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showTopUpDialog(Map<String, dynamic> user) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Get user's NFC cards
    final cards = await UserService.getUserNFCCards(user['id']);

    if (!mounted) return;

    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name']} does not have any NFC cards'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedCardId = cards.first['id'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Text('Top Up Wallet'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User: ${user['full_name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              
              // Card Selection
             // Card Selection
DropdownButtonFormField<String>(
  value: selectedCardId,
  decoration: InputDecoration(
    labelText: 'Select Card',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    prefixIcon: const Icon(Icons.credit_card),
  ),
  isExpanded: true,
  items: cards.map<DropdownMenuItem<String>>((card) {
    final balance = card['balance'] ?? 0.0;
    return DropdownMenuItem(
      value: card['id'],
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card['card_number'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              'Balance: ₱${balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }).toList(),
  onChanged: (value) {
    selectedCardId = value;
  },
  selectedItemBuilder: (BuildContext context) {
    return cards.map<Widget>((card) {
      final balance = card['balance'] ?? 0.0;
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${card['card_number']} - ₱${balance.toStringAsFixed(2)}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }).toList();
  },
),
              const SizedBox(height: 16),
              
              // Amount Input
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (₱)',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > 10000) {
                    return 'Maximum top-up amount is ₱10,000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Quick amount buttons
              Wrap(
                spacing: 8,
                children: [100, 200, 500, 1000].map((amount) {
                  return ActionChip(
                    label: Text('₱$amount'),
                    onPressed: () {
                      amountController.text = amount.toString();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() && selectedCardId != null) {
                Navigator.pop(context);
                await _processTopUp(
                  user,
                  selectedCardId!,
                  double.parse(amountController.text),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _processTopUp(
    Map<String, dynamic> user,
    String cardId,
    double amount,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await UserService.topUpCard(cardId, amount);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully topped up ₱${amount.toStringAsFixed(2)} to ${user['full_name']}\'s card',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing top-up: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['full_name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email']),
              _buildDetailRow('Phone', user['phone_number'] ?? 'N/A'),
              _buildDetailRow('Role', _capitalizeRole(user['role'])),
              _buildDetailRow(
                'Status',
                user['is_active'] ? 'Active' : 'Inactive',
              ),
              _buildDetailRow(
                'Created',
                DateFormat('MMM dd, yyyy').format(
                  DateTime.parse(user['created_at']),
                ),
              ),
              _buildDetailRow(
                'Updated',
                DateFormat('MMM dd, yyyy').format(
                  DateTime.parse(user['updated_at']),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeRole(String role) {
    return role[0].toUpperCase() + role.substring(1);
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'driver':
        return Colors.blue;
      case 'passenger':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'driver':
        return Icons.local_shipping;
      case 'passenger':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadUsers,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: _handleSearch,
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or phone...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'driver', child: Text('Driver')),
                          DropdownMenuItem(value: 'passenger', child: Text('Passenger')),
                        ],
                        onChanged: _handleRoleFilterChange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            color: Colors.white,
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'User Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Contact',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Role',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 140,
                                  alignment: Alignment.centerRight,
                                  child: const Text(
                                    'Actions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // User List
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                final isCurrentUser = user['id'] == _currentUserId;
                                return _UserCard(
                                  user: user,
                                  isCurrentUser: isCurrentUser,
                                  onToggleStatus: () => _toggleUserStatus(user),
                                  onDelete: () => _deleteUser(user),
                                  onViewDetails: () => _showUserDetails(user),
                                  onTopUp: () => _showTopUpDialog(user),
                                  getRoleColor: _getRoleColor,
                                  getRoleIcon: _getRoleIcon,
                                  capitalizeRole: _capitalizeRole,
                                );
                              },
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

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCurrentUser;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;
  final VoidCallback onTopUp;
  final Color Function(String) getRoleColor;
  final IconData Function(String) getRoleIcon;
  final String Function(String) capitalizeRole;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onViewDetails,
    required this.onTopUp,
    required this.getRoleColor,
    required this.getRoleIcon,
    required this.capitalizeRole,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] ?? true;
    final role = user['role'] ?? 'passenger';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User Name with Avatar
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: getRoleColor(role).withOpacity(0.1),
                      child: Icon(
                        getRoleIcon(role),
                        color: getRoleColor(role),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user['full_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Contact Info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['email'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user['phone_number'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        user['phone_number'],
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Role Badge
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: getRoleColor(role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        capitalizeRole(role),
                        style: TextStyle(
                          color: getRoleColor(role),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isCurrentUser) ...[
                      // Top Up Button
                      IconButton(
                        icon: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        onPressed: onTopUp,
                        tooltip: 'Top Up Wallet',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Deactivate Button
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red, size: 20),
                        onPressed: onDelete,
                        tooltip: 'Deactivate User',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ] else
                      Chip(
                        label: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
}