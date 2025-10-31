import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/transaction_service.dart';

class AdminTransactionsPage extends StatefulWidget {
  const AdminTransactionsPage({super.key});

  @override
  State<AdminTransactionsPage> createState() => _AdminTransactionsPageState();
}

class _AdminTransactionsPageState extends State<AdminTransactionsPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _selectedType;
  RealtimeChannel? _transactionsChannel;
  
  Map<String, dynamic> _statistics = {
    'total_transactions': 0,
    'successful_transactions': 0,
    'failed_transactions': 0,
    'total_revenue': 0.0,
    'total_reloads': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadStatistics();
    _subscribeToTransactions();
  }

  @override
  void dispose() {
    _transactionsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() => _isLoading = true);
      final transactions = await TransactionService.getAllTransactions(
        transactionType: _selectedType,
      );
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await TransactionService.getTransactionStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _subscribeToTransactions() {
    _transactionsChannel = TransactionService.subscribeToTransactions(
      onUpdate: (transactions) {
        if (mounted) {
          setState(() {
            _transactions = transactions;
          });
          _loadStatistics();
        }
      },
      transactionType: _selectedType,
    );
  }

  void _filterByType(String? type) {
    setState(() {
      _selectedType = type;
    });
    _transactionsChannel?.unsubscribe();
    _loadTransactions();
    _subscribeToTransactions();
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'tap_in':
        return Colors.blue;
      case 'tap_out':
        return Colors.purple;
      case 'reload':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'tap_in':
        return Icons.login;
      case 'tap_out':
        return Icons.logout;
      case 'reload':
        return Icons.add_circle;
      default:
        return Icons.receipt;
    }
  }
@override
Widget build(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  return Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    body: Column(
      children: [
        // Compact Header
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
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
                  Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _loadTransactions();
                      _loadStatistics();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 16),
              
              // Compact Statistics - Single Row on Mobile
              if (isMobile)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CompactStatCard(
                        title: 'Revenue',
                        value: _formatCurrency(_statistics['total_revenue']),
                        icon: Icons.attach_money,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      _CompactStatCard(
                        title: 'Reloads',
                        value: _formatCurrency(_statistics['total_reloads']),
                        icon: Icons.add_card,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      _CompactStatCard(
                        title: 'Success',
                        value: '${_statistics['successful_transactions']}',
                        icon: Icons.check_circle,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 8),
                      _CompactStatCard(
                        title: 'Failed',
                        value: '${_statistics['failed_transactions']}',
                        icon: Icons.error,
                        color: Colors.red.shade600,
                      ),
                    ],
                  ),
                )
              else
                // Desktop Statistics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 48) / 4;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          title: 'Total Revenue',
                          value: _formatCurrency(_statistics['total_revenue']),
                          icon: Icons.attach_money,
                          color: Colors.green.shade700,
                          width: cardWidth,
                        ),
                        _StatCard(
                          title: 'Total Reloads',
                          value: _formatCurrency(_statistics['total_reloads']),
                          icon: Icons.add_card,
                          color: Colors.blue.shade700,
                          width: cardWidth,
                        ),
                        _StatCard(
                          title: 'Successful',
                          value: '${_statistics['successful_transactions']}',
                          icon: Icons.check_circle,
                          color: Colors.green.shade600,
                          width: cardWidth,
                        ),
                        _StatCard(
                          title: 'Failed',
                          value: '${_statistics['failed_transactions']}',
                          icon: Icons.error,
                          color: Colors.red.shade600,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: isMobile ? 8 : 16),
              
              // Filter Chips - Compact
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CompactFilterChip(
                      label: 'All',
                      selected: _selectedType == null,
                      onSelected: (selected) => _filterByType(null),
                    ),
                    const SizedBox(width: 6),
                    _CompactFilterChip(
                      label: 'Tap In',
                      selected: _selectedType == 'tap_in',
                      onSelected: (selected) => _filterByType('tap_in'),
                    ),
                    const SizedBox(width: 6),
                    _CompactFilterChip(
                      label: 'Tap Out',
                      selected: _selectedType == 'tap_out',
                      onSelected: (selected) => _filterByType('tap_out'),
                    ),
                    const SizedBox(width: 6),
                    _CompactFilterChip(
                      label: 'Reload',
                      selected: _selectedType == 'reload',
                      onSelected: (selected) => _filterByType('reload'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        return _TransactionCard(
                          transaction: transaction,
                          isMobile: isMobile,
                          formatCurrency: _formatCurrency,
                          formatDateTime: _formatDateTime,
                          getStatusColor: _getStatusColor,
                          getTypeColor: _getTypeColor,
                          getTypeIcon: _getTypeIcon,
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
}

// Compact stat card for mobile horizontal scroll
class _CompactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Compact filter chip
class _CompactFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const _CompactFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelStyle: const TextStyle(fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool isMobile;
  final String Function(dynamic) formatCurrency;
  final String Function(String?) formatDateTime;
  final Color Function(String?) getStatusColor;
  final Color Function(String?) getTypeColor;
  final IconData Function(String?) getTypeIcon;

  const _TransactionCard({
    required this.transaction,
    this.isMobile = false,
    required this.formatCurrency,
    required this.formatDateTime,
    required this.getStatusColor,
    required this.getTypeColor,
    required this.getTypeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final passenger = transaction['users'];
    final nfcCard = transaction['nfc_cards'];
    final bus = transaction['buses'];
    final type = transaction['transaction_type'];
    final status = transaction['status'];
    final amount = transaction['amount'];

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: getTypeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getTypeIcon(type),
                  color: getTypeColor(type),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            type?.toUpperCase().replaceAll('_', ' ') ?? 'N/A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 13 : 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status?.toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              color: getStatusColor(status),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(transaction['created_at']),
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Text(
                  formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: type == 'reload' ? Colors.green[700] : Colors.blue[700],
                  ),
                ),
              ],
            ],
          ),
          
          // Amount on mobile
          if (isMobile) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (type == 'reload' ? Colors.green : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Amount: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    formatCurrency(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: type == 'reload' ? Colors.green[700] : Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: isMobile ? 8 : 12),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: isMobile ? 8 : 12),
          
          // Essential Transaction Details Only
          _buildDetailRow('Passenger', passenger?['full_name'] ?? 'N/A'),
          if (isMobile) ...[
            _buildDetailRow('Card', nfcCard?['card_number'] ?? 'N/A'),
            if (bus != null)
              _buildDetailRow('Bus', '${bus['bus_number']}'),
          ] else ...[
            _buildDetailRow('Email', passenger?['email'] ?? 'N/A'),
            _buildDetailRow('Card Number', nfcCard?['card_number'] ?? 'N/A'),
            if (bus != null)
              _buildDetailRow('Bus', '${bus['bus_number']} - ${bus['plate_number']}'),
          ],
          
          // Show more details in expandable section on mobile
          if (isMobile)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'More Details',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                if (passenger?['email'] != null)
                  _buildDetailRow('Email', passenger['email']),
                if (bus != null && bus['plate_number'] != null)
                  _buildDetailRow('Plate', bus['plate_number']),
                if (transaction['discount_type'] != null && transaction['discount_type'] != 'none') ...[
                  _buildDetailRow('Discount', transaction['discount_type']?.toUpperCase()),
                  _buildDetailRow('Discount Applied', formatCurrency(transaction['discount_applied'])),
                ],
                _buildDetailRow('Balance Before', formatCurrency(transaction['balance_before'])),
                _buildDetailRow('Balance After', formatCurrency(transaction['balance_after'])),
                if (transaction['location_name'] != null)
                  _buildDetailRow('Location', transaction['location_name']),
              ],
            )
          else ...[
            if (transaction['discount_type'] != null && transaction['discount_type'] != 'none') ...[
              _buildDetailRow('Discount', transaction['discount_type']?.toUpperCase()),
              _buildDetailRow('Discount Applied', formatCurrency(transaction['discount_applied'])),
            ],
            _buildDetailRow('Balance Before', formatCurrency(transaction['balance_before'])),
            _buildDetailRow('Balance After', formatCurrency(transaction['balance_after'])),
            if (transaction['location_name'] != null)
              _buildDetailRow('Location', transaction['location_name']),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      child: isMobile 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 