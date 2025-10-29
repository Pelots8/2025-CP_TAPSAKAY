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

  /// Tap In - Start a passenger trip
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

      // 3. Create passenger trip record
      final passengerTrip = await _supabase.from('passenger_trips').insert({
        'trip_id': tripId,
        'passenger_id': passengerId,
        'nfc_card_id': nfcCardId,
        'tap_in_time': DateTime.now().toIso8601String(),
        'tap_in_latitude': latitude,
        'tap_in_longitude': longitude,
        'tap_in_location': locationName,
        'status': 'ongoing',
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

      // 5. Update trip passenger count
      await _supabase.rpc('increment_trip_passengers', params: {
        'trip_id': tripId,
      });

      return {
        'success': true,
        'passenger_trip': passengerTrip,
        'transaction': transaction,
        'message': 'Tapped in successfully',
      };
    } catch (e) {
      print('Error during tap in: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Tap Out - End a passenger trip and charge fare
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

      // 2. Get NFC card details
      final card = await _supabase
          .from('nfc_cards')
          .select()
          .eq('id', nfcCardId)
          .single();

      final currentBalance = (card['balance'] ?? 0.0).toDouble();
      final discountType = card['discount_type'] ?? 'none';

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

      // 4. Calculate fare
      final baseFare = calculateFare(distanceInKm);
      final discountAmount = calculateDiscount(baseFare, discountType);
      final finalFare = baseFare - discountAmount;

      // 5. Check if card has sufficient balance
      if (currentBalance < finalFare) {
        throw Exception(
          'Insufficient balance. Fare: ₱${finalFare.toStringAsFixed(2)}, Balance: ₱${currentBalance.toStringAsFixed(2)}'
        );
      }

      final newBalance = currentBalance - finalFare;

      // 6. Update passenger trip record
      await _supabase.from('passenger_trips').update({
        'tap_out_time': DateTime.now().toIso8601String(),
        'tap_out_latitude': latitude,
        'tap_out_longitude': longitude,
        'tap_out_location': locationName,
        'distance_traveled': distanceInKm,
        'fare_amount': baseFare,
        'discount_applied': discountAmount,
        'final_amount': finalFare,
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
        'amount': finalFare,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'discount_applied': discountAmount,
        'discount_type': discountType,
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

      // 9. Update trip total fare collected
      await _supabase.rpc('update_trip_fare', params: {
        'trip_id': tripId,
        'fare_to_add': finalFare,
      });

      return {
        'success': true,
        'transaction': transaction,
        'fare': finalFare,
        'distance': distanceInKm,
        'new_balance': newBalance,
        'message': 'Tapped out successfully. Fare: ₱${finalFare.toStringAsFixed(2)}',
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
}