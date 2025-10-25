import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDriverService {
  static final _supabase = Supabase.instance.client;

  /// Get all drivers with user and bus info
  static Future<List<Map<String, dynamic>>> getAllDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('''
            *,
            users!inner(
              full_name,
              email,
              phone_number
            ),
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
      print('Error fetching drivers: $e');
      throw Exception('Failed to load drivers: ${e.toString()}');
    }
  }

  /// Get all users with passenger role (for selection when adding driver)
  static Future<List<Map<String, dynamic>>> getPassengerUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, full_name, email, phone_number')
          .eq('role', 'passenger')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching passenger users: $e');
      throw Exception('Failed to load users: ${e.toString()}');
    }
  }

  /// Get all available buses (buses with no driver assigned)
  static Future<List<Map<String, dynamic>>> getAvailableBuses() async {
    try {
      // Get all buses
      final allBuses = await _supabase
          .from('buses')
          .select('id, bus_number, plate_number, route_name')
          .order('bus_number', ascending: true);

      // Get all assigned bus IDs from drivers table
      final drivers = await _supabase
          .from('drivers')
          .select('assigned_bus_id')
          .not('assigned_bus_id', 'is', null);

      final assignedBusIds = drivers
          .map((d) => d['assigned_bus_id'])
          .where((id) => id != null)
          .toSet();

      // Filter out buses that already have a driver assigned
      final availableBuses = (allBuses as List)
          .where((bus) => !assignedBusIds.contains(bus['id']))
          .toList();

      return List<Map<String, dynamic>>.from(availableBuses);
    } catch (e) {
      print('Error fetching available buses: $e');
      throw Exception('Failed to load buses: ${e.toString()}');
    }
  }

  /// Create new driver (converts passenger to driver)
  static Future<void> createDriver({
    required String userId,
    required String licenseNumber,
    required DateTime licenseExpiryDate,
    String? assignedBusId,
  }) async {
    try {
      // 1. Update user role to driver
      await _supabase
          .from('users')
          .update({'role': 'driver'})
          .eq('id', userId);

      // 2. Create driver record
      await _supabase.from('drivers').insert({
        'id': userId,
        'driver_license_number': licenseNumber,
        'license_expiry_date': licenseExpiryDate.toIso8601String(),
        'assigned_bus_id': assignedBusId,
      });
    } catch (e) {
      print('Error creating driver: $e');
      throw Exception('Failed to create driver: ${e.toString()}');
    }
  }

  /// Update driver information
  static Future<void> updateDriver({
    required String driverId,
    required String licenseNumber,
    required DateTime licenseExpiryDate,
    String? assignedBusId,
    String? previousBusId,
  }) async {
    try {
      // Update driver record
      await _supabase.from('drivers').update({
        'driver_license_number': licenseNumber,
        'license_expiry_date': licenseExpiryDate.toIso8601String(),
        'assigned_bus_id': assignedBusId,
      }).eq('id', driverId);
    } catch (e) {
      print('Error updating driver: $e');
      throw Exception('Failed to update driver: ${e.toString()}');
    }
  }

  /// Delete driver (converts back to passenger)
  static Future<void> deleteDriver(String driverId, String? assignedBusId) async {
    try {
      // 1. Delete driver record (this will cascade)
      await _supabase.from('drivers').delete().eq('id', driverId);

      // 2. Update user role back to passenger
      await _supabase
          .from('users')
          .update({'role': 'passenger'})
          .eq('id', driverId);
    } catch (e) {
      print('Error deleting driver: $e');
      throw Exception('Failed to delete driver: ${e.toString()}');
    }
  }

  /// Get all buses for reassignment (includes current assigned bus + unassigned buses)
  static Future<List<Map<String, dynamic>>> getBusesForAssignment(
      String? currentBusId) async {
    try {
      // Get all buses
      final allBuses = await _supabase
          .from('buses')
          .select('id, bus_number, plate_number, route_name')
          .order('bus_number', ascending: true);

      // Get all assigned bus IDs from drivers table
      final drivers = await _supabase
          .from('drivers')
          .select('assigned_bus_id')
          .not('assigned_bus_id', 'is', null);

      final assignedBusIds = drivers
          .map((d) => d['assigned_bus_id'])
          .where((id) => id != null)
          .toSet();

      // Filter to show: unassigned buses OR the currently assigned bus
      final availableBuses = (allBuses as List)
          .where((bus) =>
              !assignedBusIds.contains(bus['id']) || bus['id'] == currentBusId)
          .toList();

      return List<Map<String, dynamic>>.from(availableBuses);
    } catch (e) {
      print('Error fetching buses for assignment: $e');
      throw Exception('Failed to load buses: ${e.toString()}');
    }
  }
}