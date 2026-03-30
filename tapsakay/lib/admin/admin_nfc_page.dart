import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nfc_service.dart';

class AdminNFCPage extends StatefulWidget {
  const AdminNFCPage({super.key});

  @override
  State<AdminNFCPage> createState() => _AdminNFCPageState();
}

class _AdminNFCPageState extends State<AdminNFCPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final NFCService _nfcService = NFCService();
  
  // Card registration state
  String? _scannedUID;
  bool _isScanning = false;
  final _cardNumberController = TextEditingController();
  final _selectedPassengerController = TextEditingController();
  final _initialBalanceController = TextEditingController(text: '100.00');
  List<Map<String, dynamic>> _passengers = [];
  Map<String, dynamic>? _selectedPassenger;
  
  // Top-up state
  final _topupCardController = TextEditingController();
  final _topupAmountController = TextEditingController();
  List<Map<String, dynamic>> _cards = [];
  Map<String, dynamic>? _selectedCard;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPassengers();
    _loadCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cardNumberController.dispose();
    _selectedPassengerController.dispose();
    _initialBalanceController.dispose();
    _topupCardController.dispose();
    _topupAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPassengers() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, full_name, email')
          .eq('role', 'passenger')
          .order('full_name');
      
      setState(() {
        _passengers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading passengers: $e');
    }
  }

  Future<void> _loadCards() async {
    try {
      final response = await Supabase.instance.client
          .from('nfc_cards')
          .select('''
            id,
            uid,
            card_number,
            balance,
            is_active,
            users!owner_id (
              full_name,
              email
            )
          ''')
          .order('created_at', ascending: false);
      
      setState(() {
        _cards = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading cards: $e');
    }
  }

  Future<void> _scanCard() async {
    setState(() => _isScanning = true);
    
    try {
      final uid = await _nfcService.readCard();
      
      setState(() {
        _scannedUID = uid;
        _isScanning = false;
      });
      
      if (uid != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card scanned: $uid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerCard() async {
    if (_scannedUID == null || _selectedPassenger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan card and select passenger'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await _nfcService.registerCard(
        uid: _scannedUID!,
        cardNumber: _cardNumberController.text.isEmpty 
            ? 'NFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
            : _cardNumberController.text,
        ownerId: _selectedPassenger!['id'],
        initialBalance: double.tryParse(_initialBalanceController.text) ?? 100.0,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form
        setState(() {
          _scannedUID = null;
          _cardNumberController.clear();
          _selectedPassenger = null;
          _selectedPassengerController.clear();
        });
        
        _loadCards();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _topUpCard() async {
    if (_selectedCard == null || _topupAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select card and enter amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_topupAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cardId = _selectedCard!['uid'] ?? _selectedCard!['card_number'];
      final success = await _nfcService.addBalance(cardId: cardId, amount: amount);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Top-up successful! Added ₱${amount.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );
        
        _topupAmountController.clear();
        _loadCards();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Card Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Register Card', icon: Icon(Icons.add_card)),
            Tab(text: 'Top-up Balance', icon: Icon(Icons.account_balance_wallet)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegisterCardTab(),
          _buildTopUpTab(),
        ],
      ),
    );
  }

  Widget _buildRegisterCardTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Scan Card Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Step 1: Scan NFC Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_scannedUID != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Card UID: $_scannedUID',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanCard,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.nfc),
                        label: Text(_isScanning ? 'Scanning...' : 'Scan Card'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Card Details Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Step 2: Card Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number (Optional)',
                      hintText: 'e.g., CARD-001',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initialBalanceController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Balance',
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Select Passenger Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Step 3: Select Passenger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedPassenger,
                    isExpanded: true, // Allow dropdown to expand
                    decoration: const InputDecoration(
                      labelText: 'Select Passenger',
                      hintText: 'Choose passenger...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _passengers.map((passenger) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: passenger,
                        child: Text(
                              passenger['full_name'],
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                      );
                    }).toList(),
                    onChanged: (Map<String, dynamic>? value) {
                      setState(() {
                        _selectedPassenger = value;
                        _selectedPassengerController.text = value?['full_name'] ?? '';
                      });
                    },
                  ),
                  if (_selectedPassenger != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_selectedPassenger!['full_name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Register Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_scannedUID == null || _selectedPassenger == null || _isProcessing)
                  ? null
                  : _registerCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Register Card', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTopUpTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Select Card Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Card to Top-up',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedCard,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                    hint: const Text('Choose a card'),
                    items: _cards.map((card) {
                      return DropdownMenuItem(
                        value: card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${card['card_number'] ?? card['uid']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Owner: ${card['users']?['full_name'] ?? 'Unassigned'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Balance: ₱${card['balance']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCard = value;
                        _topupCardController.text = value?['card_number'] ?? value?['uid'] ?? '';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Top-up Amount Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top-up Amount',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topupAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickAmountButton('100'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('200'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('500'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('1000'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Top-up Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedCard == null || _isProcessing) ? null : _topUpCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Top-up Balance', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          _topupAmountController.text = amount;
        },
        child: Text('₱$amount'),
      ),
    );
  }
}
