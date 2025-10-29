import 'package:supabase_flutter/supabase_flutter.dart';

class TripService {
  static final _supabase = Supabase.instance.client;

  /// Get all trips with filters
  static Future<List<Map<String, dynamic>>> getAllTrips({
    String? status, // 'ongoing', 'completed', 'cancelled'
    String? busId,
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('trips').select('''
        *,
        buses!trips_bus_id_fkey(
          id,
          bus_number,
          plate_number,
          route_name
        ),
        drivers!trips_driver_id_fkey(
          id,
          users!drivers_id_fkey(
            id,
            full_name,
            email
          )
        )
      ''');

      if (status != null) {
        query = query.eq('status', status);
      }
      if (busId != null) {
        query = query.eq('bus_id', busId);
      }
      if (driverId != null) {
        query = query.eq('driver_id', driverId);
      }
      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('start_time', endDate.toIso8601String());
      }

      final response = await query.order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching trips: $e');
      throw Exception('Failed to fetch trips: ${e.toString()}');
    }
  }

  /// Get trip statistics for admin dashboard
  static Future<Map<String, dynamic>> getTripStatistics() async {
    try {
      final allTrips = await _supabase.from('trips').select('status, total_fare_collected');

      int totalTrips = allTrips.length;
      int ongoingTrips = allTrips.where((t) => t['status'] == 'ongoing').length;
      int completedTrips = allTrips.where((t) => t['status'] == 'completed').length;
      
      double totalRevenue = 0.0;
      for (var trip in allTrips) {
        if (trip['status'] == 'completed') {
          totalRevenue += (trip['total_fare_collected'] ?? 0.0).toDouble();
        }
      }

      return {
        'total_trips': totalTrips,
        'ongoing_trips': ongoingTrips,
        'completed_trips': completedTrips,
        'total_revenue': totalRevenue,
      };
    } catch (e) {
      print('Error fetching trip statistics: $e');
      return {
        'total_trips': 0,
        'ongoing_trips': 0,
        'completed_trips': 0,
        'total_revenue': 0.0,
      };
    }
  }

  /// Start a new trip (for drivers)
  static Future<Map<String, dynamic>> startTrip({
    required String busId,
    required String driverId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      // Check if driver already has an ongoing trip
      final existingTrip = await _supabase
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'ongoing')
          .maybeSingle();

      if (existingTrip != null) {
        throw Exception('You already have an ongoing trip');
      }

      final response = await _supabase.from('trips').insert({
        'bus_id': busId,
        'driver_id': driverId,
        'start_time': DateTime.now().toIso8601String(),
        'start_latitude': latitude,
        'start_longitude': longitude,
        'start_location': locationName,
        'status': 'ongoing',
        'total_passengers': 0,
        'total_fare_collected': 0.0,
      }).select().single();

      return response;
    } catch (e) {
      print('Error starting trip: $e');
      throw Exception('Failed to start trip: ${e.toString()}');
    }
  }

  /// End a trip (for drivers)
  static Future<Map<String, dynamic>> endTrip({
    required String tripId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      final response = await _supabase.from('trips').update({
        'end_time': DateTime.now().toIso8601String(),
        'end_latitude': latitude,
        'end_longitude': longitude,
        'end_location': locationName,
        'status': 'completed',
      }).eq('id', tripId).select().single();

      return response;
    } catch (e) {
      print('Error ending trip: $e');
      throw Exception('Failed to end trip: ${e.toString()}');
    }
  }

  /// Get current ongoing trip for a driver
  static Future<Map<String, dynamic>?> getCurrentTrip(String driverId) async {
    try {
      final response = await _supabase
          .from('trips')
          .select('''
            *,
            buses!trips_bus_id_fkey(
              id,
              bus_number,
              plate_number,
              route_name
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'ongoing')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching current trip: $e');
      return null;
    }
  }

  /// Get trip details with passengers
  static Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final response = await _supabase
          .from('trips')
          .select('''
            *,
            buses!trips_bus_id_fkey(
              id,
              bus_number,
              plate_number,
              route_name
            ),
            drivers!trips_driver_id_fkey(
              id,
              users!drivers_id_fkey(
                id,
                full_name,
                email
              )
            ),
            passenger_trips!passenger_trips_trip_id_fkey(
              *,
              users!passenger_trips_passenger_id_fkey(
                id,
                full_name,
                email
              ),
              nfc_cards!passenger_trips_nfc_card_id_fkey(
                id,
                card_number,
                discount_type
              )
            )
          ''')
          .eq('id', tripId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching trip details: $e');
      return null;
    }
  }

  /// Subscribe to trip updates (for real-time monitoring)
  static RealtimeChannel subscribeToTrips({
    required Function(List<Map<String, dynamic>>) onUpdate,
    String? status,
  }) {
    final channel = _supabase.channel('trips-changes');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'trips',
      callback: (payload) async {
        // Reload all trips when any change occurs
        final trips = await getAllTrips(status: status);
        onUpdate(trips);
      },
    ).subscribe();

    return channel;
  }

  /// Cancel a trip
  static Future<void> cancelTrip(String tripId, String reason) async {
    try {
      await _supabase.from('trips').update({
        'status': 'cancelled',
        'end_time': DateTime.now().toIso8601String(),
      }).eq('id', tripId);
    } catch (e) {
      print('Error cancelling trip: $e');
      throw Exception('Failed to cancel trip: ${e.toString()}');
    }
  }
}