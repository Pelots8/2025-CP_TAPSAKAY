import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class PassengerTapService {
  static final _supabase = Supabase.instance.client;

  // Fare calculation based on distance
  static double calculateFare(double distanceInKm) {
    if (distanceInKm <= 2.0) {
      return 10.0;
    } else if (distanceInKm <= 4.0) {
      return 15.0;
    } else if (distanceInKm <= 6.0) {
      return 20.0;
    } else {
      return 30.0; // 6km and above (max fare)
    }
  }

  // Calculate discount based on discount type
  static double calculateDiscount(double fare, String? discountType) {
    switch (discountType) {
      case 'student':
        return fare * 0.20; // 20% discount
      case 'senior':
        return fare * 0.20; // 20% discount
      case 'pwd':
        return fare * 0.20; // 20% discount
      default:
        return 0.0;
    }
  }

  /// Tap In - Start a passenger trip (pending driver confirmation)
  static Future<Map<String, dynamic>> tapIn({
    required String passengerId,
    required String nfcCardId,
    required String tripId,
    required String busId,
    required String driverId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      // 1. Get NFC card details
      final cardResponse = await _supabase
          .from('nfc_cards')
          .select()
          .eq('id', nfcCardId)
          .single();

      final card = cardResponse;
      
      // Check if card is active
      if (card['is_active'] != true) {
        throw Exception('Card is not active');
      }
      
      if (card['is_blocked'] == true) {
        throw Exception('Card is blocked');
      }

      final currentBalance = (card['balance'] ?? 0.0).toDouble();
      
      // Check if card has minimum balance (at least ₱10 for minimum fare)
      if (currentBalance < 10.0) {
        throw Exception('Insufficient balance. Please reload your card.');
      }

      // 2. Check if passenger already has an ongoing trip on this bus
      final existingTrip = await _supabase
          .from('passenger_trips')
          .select()
          .eq('passenger_id', passengerId)
          .eq('trip_id', tripId)
          .eq('status', 'ongoing')
          .maybeSingle();

      if (existingTrip != null) {
        throw Exception('You already have an ongoing trip on this bus');
      }

      // 3. Create passenger trip record (pending driver confirmation)
      final passengerTrip = await _supabase.from('passenger_trips').insert({
        'trip_id': tripId,
        'passenger_id': passengerId,
        'nfc_card_id': nfcCardId,
        'tap_in_time': DateTime.now().toIso8601String(),
        'tap_in_latitude': latitude,
        'tap_in_longitude': longitude,
        'tap_in_location': locationName,
        'status': 'ongoing',
        'passenger_count': 1, // 🚀 Default to 1, driver will update
        'driver_confirmed': false, // 🚀 Waiting for driver confirmation
      }).select().single();

      // 4. Create tap-in transaction (₱0 for now, fare charged on tap out)
      final transaction = await _supabase.from('transactions').insert({
        'trip_id': tripId,
        'passenger_id': passengerId,
        'nfc_card_id': nfcCardId,
        'bus_id': busId,
        'driver_id': driverId,
        'transaction_type': 'tap_in',
        'amount': 0.0,
        'balance_before': currentBalance,
        'balance_after': currentBalance,
        'discount_type': card['discount_type'] ?? 'none',
        'location_latitude': latitude,
        'location_longitude': longitude,
        'location_name': locationName,
        'status': 'success',
      }).select().single();



      return {
        'success': true,
        'passenger_trip': passengerTrip,
        'transaction': transaction,
        'message': 'Waiting for driver confirmation...',
      };
    } catch (e) {
      print('Error during tap in: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// 🚀 NEW: Confirm passenger count (called by driver)
static Future<Map<String, dynamic>> confirmPassengerCount({
  required String passengerTripId,
  required int passengerCount,
  required String tripId,
  required Map<String, int> passengerBreakdown,
}) async {
  try {
    if (passengerCount < 1 || passengerCount > 10) {
      throw Exception('Invalid passenger count (1-10)');
    }

    // Validate breakdown matches total
    int breakdownTotal = passengerBreakdown.values.fold(0, (sum, val) => sum + val);
    if (breakdownTotal != passengerCount) {
      throw Exception('Passenger breakdown must match total count');
    }

    // 1. Update passenger trip with confirmed count AND breakdown
    final updatedTrip = await _supabase.from('passenger_trips').update({
      'passenger_count': passengerCount,
      'passenger_breakdown': passengerBreakdown,
      'driver_confirmed': true,
      'driver_confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', passengerTripId).select().single();

    // 2. 🚀 ADD THE FULL PASSENGER COUNT (not minus 1)
    await _supabase.rpc('increment_trip_passengers_by', params: {
      'trip_id': tripId,
      'count': passengerCount, // ✅ Add all passengers when confirmed
    });

    return {
      'success': true,
      'passenger_trip': updatedTrip,
      'message': 'Passenger count confirmed: $passengerCount',
    };
  } catch (e) {
    print('Error confirming passenger count: $e');
    throw Exception(e.toString().replaceAll('Exception: ', ''));
  }
}

  /// 🚀 NEW: Reject/Cancel tap in (called by driver)
  static Future<void> rejectTapIn({
    required String passengerTripId,
    required String tripId,
  }) async {
    try {
      // 1. Cancel the passenger trip
      await _supabase.from('passenger_trips').update({
        'status': 'cancelled',
      }).eq('id', passengerTripId);

      // 2. Decrement trip passenger count
      await _supabase.rpc('decrement_trip_passengers', params: {
        'trip_id': tripId,
      });
    } catch (e) {
      print('Error rejecting tap in: $e');
      throw Exception('Failed to reject tap in: ${e.toString()}');
    }
  }

  /// Tap Out - End a passenger trip and charge fare (multiplied by passenger_count)
 static Future<Map<String, dynamic>> tapOut({
  required String passengerId,
  required String nfcCardId,
  required String tripId,
  required String busId,
  required String driverId,
  required double latitude,
  required double longitude,
  String? locationName,
}) async {
  try {
    // 1. Get the ongoing passenger trip
    final passengerTrip = await _supabase
        .from('passenger_trips')
        .select()
        .eq('passenger_id', passengerId)
        .eq('trip_id', tripId)
        .eq('status', 'ongoing')
        .maybeSingle();

    if (passengerTrip == null) {
      throw Exception('No ongoing trip found. Please tap in first.');
    }

    // 🚀 Check if driver has confirmed
    if (passengerTrip['driver_confirmed'] != true) {
      throw Exception('Waiting for driver confirmation. Please try again.');
    }

    // 🚀 Get passenger count and breakdown
    final passengerCount = (passengerTrip['passenger_count'] ?? 1) as int;
    final passengerBreakdown = passengerTrip['passenger_breakdown'] as Map<String, dynamic>? 
        ?? {'regular': passengerCount, 'student': 0, 'senior': 0, 'pwd': 0};

    // 2. Get NFC card details
    final card = await _supabase
        .from('nfc_cards')
        .select()
        .eq('id', nfcCardId)
        .single();

    final currentBalance = (card['balance'] ?? 0.0).toDouble();

    // 3. Calculate distance traveled
    final tapInLat = (passengerTrip['tap_in_latitude'] ?? 0.0).toDouble();
    final tapInLng = (passengerTrip['tap_in_longitude'] ?? 0.0).toDouble();
    
    final distanceInMeters = Geolocator.distanceBetween(
      tapInLat,
      tapInLng,
      latitude,
      longitude,
    );
    
    final distanceInKm = distanceInMeters / 1000;

    // 4. 🚀 Calculate fare based on passenger breakdown
    final baseFarePerPassenger = calculateFare(distanceInKm);
    
    // Extract passenger counts by type
    final regularCount = (passengerBreakdown['regular'] ?? 0) as int;
    final studentCount = (passengerBreakdown['student'] ?? 0) as int;
    final seniorCount = (passengerBreakdown['senior'] ?? 0) as int;
    final pwdCount = (passengerBreakdown['pwd'] ?? 0) as int;
    
    // Calculate fare for each passenger type
    final regularFare = baseFarePerPassenger * regularCount;
    final studentFare = baseFarePerPassenger * 0.8 * studentCount; // 20% discount
    final seniorFare = baseFarePerPassenger * 0.8 * seniorCount;   // 20% discount
    final pwdFare = baseFarePerPassenger * 0.8 * pwdCount;         // 20% discount
    
    // Calculate totals
    final totalBaseFare = baseFarePerPassenger * passengerCount;
    final totalFinalFare = regularFare + studentFare + seniorFare + pwdFare;
    final totalDiscount = totalBaseFare - totalFinalFare;

    // 5. Check if card has sufficient balance
    if (currentBalance < totalFinalFare) {
      throw Exception(
        'Insufficient balance. Total fare for $passengerCount passenger(s): ₱${totalFinalFare.toStringAsFixed(2)}, Balance: ₱${currentBalance.toStringAsFixed(2)}'
      );
    }

    final newBalance = currentBalance - totalFinalFare;

    // 6. Update passenger trip record
    await _supabase.from('passenger_trips').update({
      'tap_out_time': DateTime.now().toIso8601String(),
      'tap_out_latitude': latitude,
      'tap_out_longitude': longitude,
      'tap_out_location': locationName,
      'distance_traveled': distanceInKm,
      'fare_amount': totalBaseFare,
      'discount_applied': totalDiscount,
      'final_amount': totalFinalFare,
      'status': 'completed',
    }).eq('id', passengerTrip['id']);

    // 7. Create tap-out transaction
    final transaction = await _supabase.from('transactions').insert({
      'trip_id': tripId,
      'passenger_id': passengerId,
      'nfc_card_id': nfcCardId,
      'bus_id': busId,
      'driver_id': driverId,
      'transaction_type': 'tap_out',
      'amount': totalFinalFare,
      'balance_before': currentBalance,
      'balance_after': newBalance,
      'discount_applied': totalDiscount,
      'discount_type': 'none', // 🚀 Changed from single type to 'mixed' for breakdown
      'location_latitude': latitude,
      'location_longitude': longitude,
      'location_name': locationName,
      'status': 'success',
    }).select().single();

    // 8. Update NFC card balance
    await _supabase.from('nfc_cards').update({
      'balance': newBalance,
      'last_used_at': DateTime.now().toIso8601String(),
    }).eq('id', nfcCardId);


// 9. Update trip total fare collected (direct update method)
try {
  print('🔵 Updating trip fare...');
  
  // Get current trip data
  final tripData = await _supabase
      .from('trips')
      .select('total_fare_collected')
      .eq('id', tripId)
      .single();
  
  final currentFare = (tripData['total_fare_collected'] ?? 0.0).toDouble();
  final newFare = currentFare + totalFinalFare;
  
  print('   Current: ₱${currentFare.toStringAsFixed(2)}');
  print('   Adding: ₱${totalFinalFare.toStringAsFixed(2)}');
  print('   New total: ₱${newFare.toStringAsFixed(2)}');
  
  // Update the trip
  final updateResult = await _supabase
      .from('trips')
      .update({
        'total_fare_collected': newFare,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', tripId)
      .select('total_fare_collected');
  
  print('✅ Trip fare updated successfully!');
  print('   Result: $updateResult');
  
  if (updateResult.isNotEmpty) {
    final confirmedFare = updateResult[0]['total_fare_collected'];
    print('   Confirmed fare in DB: ₱${confirmedFare}');
  }
} catch (e) {
  print('❌ ERROR updating trip fare: $e');
  print('   Type: ${e.runtimeType}');
  print('   Stack: ${e.toString()}');
}

    // 🚀 Build detailed breakdown message
    String breakdownMessage = 'Tapped out successfully.\n';
    breakdownMessage += '$passengerCount passenger(s) total:\n';
    if (regularCount > 0) breakdownMessage += '• $regularCount Regular: ₱${regularFare.toStringAsFixed(2)}\n';
    if (studentCount > 0) breakdownMessage += '• $studentCount Student: ₱${studentFare.toStringAsFixed(2)}\n';
    if (seniorCount > 0) breakdownMessage += '• $seniorCount Senior: ₱${seniorFare.toStringAsFixed(2)}\n';
    if (pwdCount > 0) breakdownMessage += '• $pwdCount PWD: ₱${pwdFare.toStringAsFixed(2)}\n';
    breakdownMessage += 'Total: ₱${totalFinalFare.toStringAsFixed(2)}';

    return {
      'success': true,
      'transaction': transaction,
      'fare': totalFinalFare,
      'passenger_count': passengerCount,
      'passenger_breakdown': passengerBreakdown,
      'fare_breakdown': {
        'regular': regularFare,
        'student': studentFare,
        'senior': seniorFare,
        'pwd': pwdFare,
      },
      'distance': distanceInKm,
      'new_balance': newBalance,
      'message': breakdownMessage,
    };
  } catch (e) {
    print('Error during tap out: $e');
    throw Exception(e.toString().replaceAll('Exception: ', ''));
  }
}

  /// Get passenger's current ongoing trip
  static Future<Map<String, dynamic>?> getCurrentPassengerTrip(String passengerId) async {
    try {
      final response = await _supabase
          .from('passenger_trips')
          .select('''
            *,
            trips!passenger_trips_trip_id_fkey(
              id,
              status,
              buses!trips_bus_id_fkey(
                id,
                bus_number,
                route_name
              ),
              drivers!trips_driver_id_fkey(
                id,
                users!drivers_id_fkey(
                  id,
                  full_name
                )
              )
            ),
            nfc_cards!passenger_trips_nfc_card_id_fkey(
              id,
              card_number,
              balance,
              discount_type
            )
          ''')
          .eq('passenger_id', passengerId)
          .eq('status', 'ongoing')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching current passenger trip: $e');
      return null;
    }
  }

  /// Get passenger trip history
  static Future<List<Map<String, dynamic>>> getPassengerTripHistory(
    String passengerId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('passenger_trips')
          .select('''
            *,
            trips!passenger_trips_trip_id_fkey(
              id,
              start_time,
              buses!trips_bus_id_fkey(
                id,
                bus_number,
                route_name
              )
            ),
            nfc_cards!passenger_trips_nfc_card_id_fkey(
              id,
              card_number
            )
          ''')
          .eq('passenger_id', passengerId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching trip history: $e');
      throw Exception('Failed to fetch trip history: ${e.toString()}');
    }
  }

  /// 🚀 NEW: Get pending tap-ins for driver to confirm
  static Future<List<Map<String, dynamic>>> getPendingTapIns(String tripId) async {
    try {
      final response = await _supabase
          .from('passenger_trips')
          .select('''
            *,
            users!passenger_trips_passenger_id_fkey(
              id,
              full_name,
              email
            ),
            nfc_cards!passenger_trips_nfc_card_id_fkey(
              id,
              card_number,
              balance,
              discount_type
            )
          ''')
          .eq('trip_id', tripId)
          .eq('status', 'ongoing')
          .eq('driver_confirmed', false)
          .order('tap_in_time', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching pending tap-ins: $e');
      return [];
    }
  }
}