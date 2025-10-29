import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class DriverService {
  static final _supabase = Supabase.instance.client;

  // 🚀 FIX: Updated to use the correct Postgrest builder pattern for counting.
  /// Get driver and passenger statistics (for admin dashboard)
  static Future<Map<String, int>> getDriverStatistics() async {
    try {
      // 1. Get total drivers and active drivers
      final allDrivers = await _supabase.from('drivers').select('is_on_duty');

      int totalDrivers = allDrivers.length;
      int activeDrivers =
          allDrivers.where((driver) => driver['is_on_duty'] == true).length;
      
      // 2. Get total passengers
      // CORRECTED: Using .select().count(CountOption.exact).limit(0) and .execute()
      // to retrieve only the count metadata.
      final countResponse = await _supabase
          .from('users')
          .select('*') // Select any column
          .count(CountOption.exact) // Specify that we want an exact count
          .limit(0) // Prevents fetching any actual data, only metadata
          .execute();
      
      // The count is now available on the response object
      final totalPassengers = countResponse.count ?? 0;

      return {
        'total_drivers': totalDrivers,
        'active_drivers': activeDrivers,
        'total_passengers': totalPassengers,
      };
    } catch (e) {
      print('Error fetching driver statistics: $e');
      return {
        'total_drivers': 0,
        'active_drivers': 0,
        'total_passengers': 0,
      };
    }
  }

  // 🚀 NEW CRUD METHOD: Get all drivers (for AdminDriversPage)
  static Future<List<Map<String, dynamic>>> getAllDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('''
            *,
            users!inner(id, full_name, email),
            buses!drivers_assigned_bus_id_fkey(
              id,
              bus_number,
              plate_number,
              route_name
            )
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all drivers: $e');
      throw Exception('Failed to fetch drivers: ${e.toString()}');
    }
  }

  // 🚀 NEW CRUD METHOD: Create a new driver record
  /// Links a user (who must already exist in the 'users' table) to a 'drivers' record.
  static Future<Map<String, dynamic>> createDriver({
    required String userId,
    String? assignedBusId,
  }) async {
    try {
      final response = await _supabase.from('drivers').insert({
        'id': userId, // Assuming 'id' in 'drivers' is a foreign key to 'users.id'
        'assigned_bus_id': assignedBusId,
        'is_on_duty': false,
      }).select().single();

      return response;
    } catch (e) {
      print('Error creating driver: $e');
      throw Exception('Failed to create driver record: ${e.toString()}');
    }
  }

  // 🚀 NEW CRUD METHOD: Delete a driver record
  static Future<void> deleteDriver(String driverId) async {
    try {
      // NOTE: Cascade delete on bus assignment if needed is handled on the DB level.
      await _supabase.from('drivers').delete().eq('id', driverId);
    } catch (e) {
      print('Error deleting driver: $e');
      throw Exception('Failed to delete driver: ${e.toString()}');
    }
  }

  /// Get driver profile with assigned bus info
  /// Note: Driver record must be created by admin first
  static Future<Map<String, dynamic>?> getDriverProfile(String userId) async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('''
            *,
            buses!drivers_assigned_bus_id_fkey(
              id,
              bus_number,
              plate_number,
              route_name,
              route_description,
              capacity,
              status
            )
          ''')
          .eq('id', userId) 
          .maybeSingle();

      if (response == null) {
        print('Driver record not found for user $userId');
        print('Driver records must be created by an admin first');
      }

      return response;
    } catch (e) {
      print('Error fetching driver profile: $e');
      return null;
    }
  }


/// Set driver on duty status
static Future<void> setOnDutyStatus({
  required String driverId,
  required bool isOnDuty,
  double? latitude,
  double? longitude,
  String? currentTripId, // 🚀 ADD THIS PARAMETER
}) async {
  try {
    final Map<String, dynamic> updateData = {
      'is_on_duty': isOnDuty,
      'current_trip_id': currentTripId, // 🚀 ADD THIS
    };

    if (isOnDuty && latitude != null && longitude != null) {
      updateData['current_latitude'] = latitude;
      updateData['current_longitude'] = longitude;
    } else if (!isOnDuty) {
      updateData['current_latitude'] = null;
      updateData['current_longitude'] = null;
      updateData['current_trip_id'] = null; // 🚀 Clear trip ID when going off duty
    }

    await _supabase
        .from('drivers')
        .update(updateData)
        .eq('id', driverId);
  } catch (e) {
    print('Error setting duty status: $e');
    throw Exception('Failed to update duty status: ${e.toString()}');
  }
}

  /// Update driver location
  static Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      print('Error updating location: $e');
      // Don't throw error for location updates to avoid disrupting the app
    }
  }

  /// Check if driver has permission to access location
  static Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Start location tracking stream
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
}

extension on ResponsePostgrestBuilder<PostgrestResponse<PostgrestList>, PostgrestList, PostgrestList> {
  limit(int i) {}
}