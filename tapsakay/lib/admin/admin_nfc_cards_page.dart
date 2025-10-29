import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/nfc_card_service.dart';
import '../services/user_service.dart';

class AdminNFCCardsPage extends StatefulWidget {
  const AdminNFCCardsPage({super.key});

  @override
  State<AdminNFCCardsPage> createState() => _AdminNFCCardsPageState();
}

class _AdminNFCCardsPageState extends State<AdminNFCCardsPage> {
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _filteredCards = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    try {
      final cards = await NFCCardService.getAllCards();
      setState(() {
        _cards = cards;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cards: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredCards = _cards.where((card) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          (card['card_number']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (card['owner_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      // Status filter
      final isActive = card['is_active'] ?? true;
      final matchesStatus = _selectedStatusFilter == 'all' ||
          (_selectedStatusFilter == 'active' && isActive) ||
          (_selectedStatusFilter == 'inactive' && !isActive);

      // Type filter
      final matchesType = _selectedTypeFilter == 'all' ||
          card['card_type'] == _selectedTypeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _handleFilterChange() {
    setState(() {
      _applyFilters();
    });
  }

  Future<void> _showCreateCardDialog() async {
    final cardNumberController = TextEditingController();
    final initialBalanceController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    
    String selectedCardType = 'reloadable';
    String selectedDiscountType = 'none';
    String? selectedUserId;
    List<Map<String, dynamic>> users = [];

    // Load users
    try {
      users = await UserService.getUsers(roleFilter: 'passenger');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.credit_card, color: Colors.blue),
              SizedBox(width: 12),
              Text('Create NFC Card'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card Number
                  TextFormField(
                    controller: cardNumberController,
                    decoration: InputDecoration(
                      labelText: 'Card Number *',
                      hintText: 'e.g., CARD-001',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (value.length < 4) {
                        return 'Card number must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Card Type
                  DropdownButtonFormField<String>(
                    value: selectedCardType,
                    decoration: InputDecoration(
                      labelText: 'Card Type *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'reloadable',
                        child: Text('Reloadable'),
                      ),
                      DropdownMenuItem(
                        value: 'single_use',
                        child: Text('Single Use'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCardType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Owner Selection
                  DropdownButtonFormField<String>(
                    value: selectedUserId,
                    decoration: InputDecoration(
                      labelText: 'Assign to User (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('-- Unassigned --'),
                      ),
                      ...users.map((user) => DropdownMenuItem(
                        value: user['id'],
                        child: Text(user['full_name'] ?? user['email']),
                      )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedUserId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Initial Balance
                  TextFormField(
                    controller: initialBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Initial Balance (₱)',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter initial balance';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Discount Type
                  DropdownButtonFormField<String>(
                    value: selectedDiscountType,
                    decoration: InputDecoration(
                      labelText: 'Discount Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.discount),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'senior', child: Text('Senior Citizen')),
                      DropdownMenuItem(value: 'pwd', child: Text('PWD')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDiscountType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _createCard(
                    cardNumber: cardNumberController.text,
                    cardType: selectedCardType,
                    ownerId: selectedUserId,
                    initialBalance: double.parse(initialBalanceController.text),
                    discountType: selectedDiscountType,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Card'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCard({
    required String cardNumber,
    required String cardType,
    String? ownerId,
    required double initialBalance,
    required String discountType,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await NFCCardService.createCard(
        cardNumber: cardNumber,
        cardType: cardType,
        ownerId: ownerId,
        initialBalance: initialBalance,
        discountType: discountType,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCards();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleCardStatus(Map<String, dynamic> card) async {
    final bool newStatus = !(card['is_active'] ?? true);
    try {
      await NFCCardService.updateCardStatus(card['id'], newStatus);
      _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Card ${newStatus ? "activated" : "deactivated"} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating card status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCard(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Are you sure you want to delete card ${card['card_number']}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await NFCCardService.deleteCard(card['id']);
        _loadCards();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Card deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting card: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showCardDetails(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.credit_card,
              color: _getCardTypeColor(card['card_type']),
            ),
            const SizedBox(width: 12),
            Text(card['card_number']),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Card Type', _capitalizeText(card['card_type'])),
              _buildDetailRow('Owner', card['owner_name'] ?? 'Unassigned'),
              _buildDetailRow('Balance', '₱${(card['balance'] ?? 0.0).toStringAsFixed(2)}'),
              _buildDetailRow('Discount', _capitalizeText(card['discount_type'] ?? 'none')),
              _buildDetailRow(
                'Status',
                (card['is_active'] ?? true) ? 'Active' : 'Inactive',
              ),
              _buildDetailRow(
                'Blocked',
                (card['is_blocked'] ?? false) ? 'Yes' : 'No',
              ),
              if (card['last_used_at'] != null)
                _buildDetailRow(
                  'Last Used',
                  DateFormat('MMM dd, yyyy HH:mm').format(
                    DateTime.parse(card['last_used_at']),
                  ),
                ),
              if (card['expiry_date'] != null)
                _buildDetailRow(
                  'Expires',
                  DateFormat('MMM dd, yyyy').format(
                    DateTime.parse(card['expiry_date']),
                  ),
                ),
              _buildDetailRow(
                'Created',
                DateFormat('MMM dd, yyyy').format(
                  DateTime.parse(card['created_at']),
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
            width: 100,
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

  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }

  Color _getCardTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'reloadable':
        return Colors.blue;
      case 'single_use':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getDiscountColor(String? discount) {
    switch (discount?.toLowerCase()) {
      case 'student':
        return Colors.purple;
      case 'senior':
        return Colors.green;
      case 'pwd':
        return Colors.teal;
      default:
        return Colors.grey;
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
                      'NFC Card Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showCreateCardDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Card'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadCards,
                          tooltip: 'Refresh',
                        ),
                      ],
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
                          hintText: 'Search by card number or owner...',
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
                        value: _selectedTypeFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Types')),
                          DropdownMenuItem(value: 'reloadable', child: Text('Reloadable')),
                          DropdownMenuItem(value: 'single_use', child: Text('Single Use')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTypeFilter = value!;
                            _handleFilterChange();
                          });
                        },
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
                        value: _selectedStatusFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatusFilter = value!;
                            _handleFilterChange();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.credit_card_off,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No cards found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: _filteredCards.length,
                        itemBuilder: (context, index) {
                          final card = _filteredCards[index];
                          return _NFCCardWidget(
                            card: card,
                            onTap: () => _showCardDetails(card),
                            onToggleStatus: () => _toggleCardStatus(card),
                            onDelete: () => _deleteCard(card),
                            getCardTypeColor: _getCardTypeColor,
                            getDiscountColor: _getDiscountColor,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NFCCardWidget extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final Color Function(String?) getCardTypeColor;
  final Color Function(String?) getDiscountColor;

  const _NFCCardWidget({
    required this.card,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
    required this.getCardTypeColor,
    required this.getDiscountColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = card['is_active'] ?? true;
    final balance = (card['balance'] ?? 0.0).toDouble();
    final cardType = card['card_type'] ?? 'reloadable';
    final discountType = card['discount_type'] ?? 'none';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                getCardTypeColor(cardType),
                getCardTypeColor(cardType).withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cardType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: onToggleStatus,
                        child: Row(
                          children: [
                            Icon(
                              isActive ? Icons.block : Icons.check_circle,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: onDelete,
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Card Number
              Text(
                card['card_number'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              // Owner and Balance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OWNER',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card['owner_name'] ?? 'Unassigned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'BALANCE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status and Discount badges
              Row(
                children: [
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'INACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (discountType != 'none') ...[
                    if (!isActive) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        discountType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}