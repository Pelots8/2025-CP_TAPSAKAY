import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverService {
  static Future<Map<String, dynamic>?> getDriverProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('drivers')
          .select('*, buses(*)')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error getting driver profile: $e');
      return null;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting position: $e');
      return null;
    }
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  static Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await Supabase.instance.client
          .from('drivers')
          .update({'current_latitude': latitude, 'current_longitude': longitude})
          .eq('id', driverId);
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  static Future<void> setOnDutyStatus({
    required String driverId,
    required bool isOnDuty,
    double? latitude,
    double? longitude,
    String? currentTripId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'is_on_duty': isOnDuty,
        'current_trip_id': currentTripId,
      };

      if (latitude != null && longitude != null) {
        updateData['current_latitude'] = latitude;
        updateData['current_longitude'] = longitude;
      }

      await Supabase.instance.client
          .from('drivers')
          .update(updateData)
          .eq('id', driverId);
    } catch (e) {
      print('Error setting duty status: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDriverStatistics() async {
    try {
      final activeDrivers = await Supabase.instance.client
          .from('drivers')
          .select('id')
          .eq('is_on_duty', true)
          .count();

      final totalPassengers = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('role', 'passenger')
          .count();

      return {
        'active_drivers': activeDrivers.count,
        'total_passengers': totalPassengers.count,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'active_drivers': 0,
        'total_passengers': 0,
      };
    }
  }
}
