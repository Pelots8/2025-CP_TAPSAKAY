import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionService {
  static final _supabase = Supabase.instance.client;

  /// Get all transactions with filters
  static Future<List<Map<String, dynamic>>> getAllTransactions({
    String? transactionType, // 'tap_in', 'tap_out', 'reload'
    String? passengerId,
    String? busId,
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('transactions').select('''
        *,
        users!transactions_passenger_id_fkey(
          id,
          full_name,
          email
        ),
        nfc_cards!transactions_nfc_card_id_fkey(
          id,
          card_number,
          card_type,
          discount_type
        ),
        buses!transactions_bus_id_fkey(
          id,
          bus_number,
          plate_number
        ),
        drivers!transactions_driver_id_fkey(
          id,
          users!drivers_id_fkey(
            id,
            full_name
          )
        ),
        trips!transactions_trip_id_fkey(
          id,
          start_time,
          status
        )
      ''');

      if (transactionType != null) {
        query = query.eq('transaction_type', transactionType);
      }
      if (passengerId != null) {
        query = query.eq('passenger_id', passengerId);
      }
      if (busId != null) {
        query = query.eq('bus_id', busId);
      }
      if (driverId != null) {
        query = query.eq('driver_id', driverId);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching transactions: $e');
      throw Exception('Failed to fetch transactions: ${e.toString()}');
    }
  }

  /// Get transaction statistics
  static Future<Map<String, dynamic>> getTransactionStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('transactions').select('transaction_type, amount, status');

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final allTransactions = await query;

      int totalTransactions = allTransactions.length;
      int successfulTransactions = allTransactions.where((t) => t['status'] == 'success').length;
      int failedTransactions = allTransactions.where((t) => t['status'] == 'failed').length;

      double totalRevenue = 0.0;
      double totalReloads = 0.0;

      for (var transaction in allTransactions) {
        if (transaction['status'] == 'success') {
          double amount = (transaction['amount'] ?? 0.0).toDouble();
          if (transaction['transaction_type'] == 'tap_out') {
            totalRevenue += amount;
          } else if (transaction['transaction_type'] == 'reload') {
            totalReloads += amount;
          }
        }
      }

      return {
        'total_transactions': totalTransactions,
        'successful_transactions': successfulTransactions,
        'failed_transactions': failedTransactions,
        'total_revenue': totalRevenue,
        'total_reloads': totalReloads,
      };
    } catch (e) {
      print('Error fetching transaction statistics: $e');
      return {
        'total_transactions': 0,
        'successful_transactions': 0,
        'failed_transactions': 0,
        'total_revenue': 0.0,
        'total_reloads': 0.0,
      };
    }
  }

  /// Create a reload transaction (for admins/kiosks)
  static Future<Map<String, dynamic>> createReloadTransaction({
    required String nfcCardId,
    required String passengerId,
    required double amount,
    required double balanceBefore,
    String? adminId,
  }) async {
    try {
      final balanceAfter = balanceBefore + amount;

      // Create transaction
      final transaction = await _supabase.from('transactions').insert({
        'passenger_id': passengerId,
        'nfc_card_id': nfcCardId,
        'transaction_type': 'reload',
        'amount': amount,
        'balance_before': balanceBefore,
        'balance_after': balanceAfter,
        'status': 'success',
        'admin_id': adminId,
      }).select().single();

      // Update NFC card balance
      await _supabase.from('nfc_cards').update({
        'balance': balanceAfter,
      }).eq('id', nfcCardId);

      return transaction;
    } catch (e) {
      print('Error creating reload transaction: $e');
      throw Exception('Failed to process reload: ${e.toString()}');
    }
  }

  /// Get user transaction history (for passengers)
  static Future<List<Map<String, dynamic>>> getUserTransactions(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            nfc_cards!transactions_nfc_card_id_fkey(
              id,
              card_number
            ),
            buses!transactions_bus_id_fkey(
              id,
              bus_number,
              route_name
            ),
            trips!transactions_trip_id_fkey(
              id,
              start_time,
              status
            )
          ''')
          .eq('passenger_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user transactions: $e');
      throw Exception('Failed to fetch transaction history: ${e.toString()}');
    }
  }

  /// Subscribe to transaction updates (for real-time monitoring)
  static RealtimeChannel subscribeToTransactions({
    required Function(List<Map<String, dynamic>>) onUpdate,
    String? transactionType,
  }) {
    final channel = _supabase.channel('transactions-changes');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'transactions',
      callback: (payload) async {
        // Reload all transactions when any change occurs
        final transactions = await getAllTransactions(
          transactionType: transactionType,
        );
        onUpdate(transactions);
      },
    ).subscribe();

    return channel;
  }

  /// Get daily revenue report
  static Future<Map<String, dynamic>> getDailyRevenue(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final transactions = await getAllTransactions(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      double totalRevenue = 0.0;
      double totalReloads = 0.0;
      int tapInCount = 0;
      int tapOutCount = 0;
      int reloadCount = 0;

      for (var transaction in transactions) {
        if (transaction['status'] == 'success') {
          double amount = (transaction['amount'] ?? 0.0).toDouble();
          
          switch (transaction['transaction_type']) {
            case 'tap_in':
              tapInCount++;
              break;
            case 'tap_out':
              tapOutCount++;
              totalRevenue += amount;
              break;
            case 'reload':
              reloadCount++;
              totalReloads += amount;
              break;
          }
        }
      }

      return {
        'date': date.toIso8601String(),
        'total_revenue': totalRevenue,
        'total_reloads': totalReloads,
        'tap_in_count': tapInCount,
        'tap_out_count': tapOutCount,
        'reload_count': reloadCount,
        'total_transactions': transactions.length,
      };
    } catch (e) {
      print('Error fetching daily revenue: $e');
      throw Exception('Failed to fetch daily revenue: ${e.toString()}');
    }
  }
}