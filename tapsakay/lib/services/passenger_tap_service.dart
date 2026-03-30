import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class PassengerTapService {
  static final _supabase = Supabase.instance.client;

  // Create a new tap-in record
  static Future<void> tapIn({
    required String passengerId,
    required String nfcCardId,
    required String tripId,
    required String busId,
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Check if user already has an ongoing tap-in
      final existingTapIn = await _supabase
          .from('passenger_trips')
          .select('id')
          .eq('passenger_id', passengerId)
          .eq('status', 'ongoing')
          .maybeSingle();
      
      if (existingTapIn != null) {
        throw Exception('You already have an ongoing trip. Please tap out first.');
      }

      await _supabase.from('passenger_trips').insert({
        'passenger_id': passengerId,
        'nfc_card_id': nfcCardId,
        'trip_id': tripId,
        'tap_in_latitude': latitude,
        'tap_in_longitude': longitude,
        'tap_in_time': DateTime.now().toIso8601String(),
        'status': 'ongoing',
        'passenger_count': 1,
        'driver_confirmed': false,
      });
    } catch (e) {
      throw Exception('Failed to tap in: ${e.toString()}');
    }
  }

  // Complete a tap-out record and calculate fare
  static Future<void> tapOut({
    required String passengerId,
    required String nfcCardId,
    required String tripId,
    required String busId,
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Get the tap-in record
      final tapInRecord = await _supabase
          .from('passenger_trips')
          .select('*')
          .eq('passenger_id', passengerId)
          .eq('nfc_card_id', nfcCardId)
          .eq('trip_id', tripId)
          .eq('status', 'ongoing')
          .order('tap_in_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (tapInRecord == null) {
        throw Exception('No active tap-in record found');
      }

      // Parse coordinates safely
      final tapInLat = double.tryParse(tapInRecord['tap_in_latitude'].toString()) ?? 0.0;
      final tapInLng = double.tryParse(tapInRecord['tap_in_longitude'].toString()) ?? 0.0;
      
      // Calculate distance in kilometers
      final distanceKm = _calculateDistance(tapInLat, tapInLng, latitude, longitude);
      
      // Convert to meters for more precise fare calculation
      final distanceMeters = distanceKm * 1000;
      
      // Debug logging
      print('=== FARE CALCULATION ===');
      print('Tap-in: ($tapInLat, $tapInLng)');
      print('Tap-out: ($latitude, $longitude)');
      print('Distance: ${distanceKm.toStringAsFixed(4)} km (${distanceMeters.toStringAsFixed(2)} meters)');
      
      // Fare calculation:
      // - Base fare: ₱10.00 (minimum fare for first 1km)
      // - Per km rate: ₱2.00 per km after first 1km
      const baseFare = 10.0;
      const perKmRate = 2.0; // ₱2.00 per km after first 1km
      const freeDistanceKm = 1.0; // First 1km is included in base fare
      
      double fare;
      if (distanceKm <= freeDistanceKm) {
        // Minimum fare for trips up to 1km
        fare = baseFare;
      } else {
        // Base fare + distance-based fare for distance beyond 1km
        fare = baseFare + ((distanceKm - freeDistanceKm) * perKmRate);
      }
      
      // Round to 2 decimal places
      fare = double.parse(fare.toStringAsFixed(2));
      
      print('Fare: ₱${fare.toStringAsFixed(2)} (base: ₱$baseFare + ${(distanceKm - freeDistanceKm).toStringAsFixed(2)}km × ₱$perKmRate)');

      // Get NFC card to check balance
      final card = await _supabase
          .from('nfc_cards')
          .select('balance')
          .eq('id', nfcCardId)
          .single();

      if (card == null) {
        throw Exception('NFC card not found');
      }

      // Parse balance as double (database returns string for numeric type)
      final currentBalance = double.tryParse(card['balance'].toString()) ?? 0.0;
      if (currentBalance < fare) {
        throw Exception('Insufficient balance');
      }
      
      final newBalance = currentBalance - fare;

      // Update passenger trip with tap-out details, fare, and distance
      await _supabase
          .from('passenger_trips')
          .update({
            'tap_out_latitude': latitude,
            'tap_out_longitude': longitude,
            'tap_out_time': DateTime.now().toIso8601String(),
            'fare_amount': fare,
            'final_amount': fare,
            'distance_traveled': distanceKm,
            'status': 'completed',
          })
          .eq('id', tapInRecord['id']);

      // Deduct fare from NFC card
      await _supabase
          .from('nfc_cards')
          .update({
            'balance': newBalance,
          })
          .eq('id', nfcCardId);

      // Create transaction record
      await _supabase.from('transactions').insert({
        'nfc_card_id': nfcCardId,
        'passenger_id': passengerId,
        'trip_id': tripId,
        'bus_id': busId,
        'driver_id': driverId,
        'transaction_type': 'tap_out',
        'amount': fare,
        'balance_before': currentBalance,
        'balance_after': currentBalance - fare,
        'status': 'success',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to tap out: ${e.toString()}');
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  static Future<List<Map<String, dynamic>>> getPendingTapIns(String tripId) async {
    try {
      final response = await Supabase.instance.client
          .from('passenger_trips')
          .select('''
            *,
            passenger:users(full_name),
            nfc_card:nfc_cards(card_number, balance)
          ''')
          .eq('trip_id', tripId)
          .eq('status', 'pending')
          .order('tap_in_time', ascending: true);

      // Add time_ago calculation
      final now = DateTime.now();
      return response.map((trip) {
        final tapInTime = DateTime.parse(trip['tap_in_time']);
        final secondsAgo = now.difference(tapInTime).inSeconds;
        return {
          ...trip,
          'time_ago': secondsAgo,
        };
      }).toList();
    } catch (e) {
      print('Error getting pending tap-ins: $e');
      return [];
    }
  }

  static Future<void> confirmPassengerCount({
    required String passengerTripId,
    required int passengerCount,
    required String tripId,
    required Map<String, int> passengerBreakdown,
  }) async {
    try {
      // Update passenger trip with confirmed count
      await Supabase.instance.client
          .from('passenger_trips')
          .update({
        'status': 'confirmed',
        'passenger_count': passengerCount,
        'passenger_breakdown': passengerBreakdown,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', passengerTripId);

      // Create transaction record
      final fare = 10.0; // Fixed fare
      final discount = _calculateDiscount(passengerBreakdown);
      final totalFare = fare * passengerCount * (1 - discount);

      await Supabase.instance.client.from('transactions').insert({
        'passenger_trip_id': passengerTripId,
        'trip_id': tripId,
        'amount': totalFare,
        'type': 'fare',
        'passenger_count': passengerCount,
        'passenger_breakdown': passengerBreakdown,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Deduct from NFC card balance
      final cardId = await Supabase.instance.client
          .from('passenger_trips')
          .select('nfc_card_id')
          .eq('id', passengerTripId)
          .single()
          .then((value) => value['nfc_card_id']);

      if (cardId != null) {
        await Supabase.instance.client.rpc('deduct_balance', params: {
          'card_id': cardId,
          'amount': totalFare,
        });
      }
    } catch (e) {
      print('Error confirming passenger count: $e');
      rethrow;
    }
  }

  static Future<void> rejectTapIn({
    required String passengerTripId,
    required String tripId,
  }) async {
    try {
      await Supabase.instance.client
          .from('passenger_trips')
          .update({
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      }).eq('id', passengerTripId);
    } catch (e) {
      print('Error rejecting tap-in: $e');
      rethrow;
    }
  }

  static double _calculateDiscount(Map<String, int> breakdown) {
    int totalDiscounted = (breakdown['student'] ?? 0) +
        (breakdown['senior'] ?? 0) +
        (breakdown['pwd'] ?? 0);
    
    if (totalDiscounted == 0) return 0.0;
    
    // 20% discount for students, seniors, and PWD
    return (totalDiscounted * 0.2) / breakdown.values.fold(0, (a, b) => a + b);
  }
}
