// bus_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class BusService {
  static final _supabase = Supabase.instance.client;

  /// Get all active buses with on-duty drivers
  static Future<List<Map<String, dynamic>>> getActiveBuses() async {
    try {
      // Get all drivers who are on duty
      final response = await _supabase
          .from('drivers')
          .select('''
            *,
            users!inner(id, full_name, email),
            buses!drivers_assigned_bus_id_fkey(
              id,
              bus_number,
              plate_number,
              route_name,
              route_description,
              status
            )
          ''')
          .eq('is_on_duty', true)
          .not('assigned_bus_id', 'is', null);

      print('Active buses response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching active buses: $e');
      return [];
    }
  }

  /// Get all buses (for admin)
  static Future<List<Map<String, dynamic>>> getAllBuses() async {
    try {
      final response = await _supabase
          .from('buses')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching buses: $e');
      throw Exception('Failed to fetch buses: ${e.toString()}');
    }
  }

  /// Get single bus by ID
  static Future<Map<String, dynamic>?> getBusById(String busId) async {
    try {
      final response = await _supabase
          .from('buses')
          .select('*')
          .eq('id', busId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching bus: $e');
      return null;
    }
  }

  /// Create new bus (admin only)
  static Future<Map<String, dynamic>> createBus({
    required String busNumber,
    required String plateNumber,
    required int capacity,
    required String routeName,
    String? routeDescription,
  }) async {
    try {
      final response = await _supabase.from('buses').insert({
        'bus_number': busNumber,
        'plate_number': plateNumber,
        'capacity': capacity,
        'route_name': routeName,
        'route_description': routeDescription,
        'status': 'inactive',
        'is_available': true,
      }).select().single();

      return response;
    } catch (e) {
      print('Error creating bus: $e');
      throw Exception('Failed to create bus: ${e.toString()}');
    }
  }

  /// Update bus (admin only)
  static Future<Map<String, dynamic>> updateBus({
    required String busId,
    String? busNumber,
    String? plateNumber,
    int? capacity,
    String? routeName,
    String? routeDescription,
    String? status,
    bool? isAvailable,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (busNumber != null) updateData['bus_number'] = busNumber;
      if (plateNumber != null) updateData['plate_number'] = plateNumber;
      if (capacity != null) updateData['capacity'] = capacity;
      if (routeName != null) updateData['route_name'] = routeName;
      if (routeDescription != null)
        updateData['route_description'] = routeDescription;
      if (status != null) updateData['status'] = status;
      if (isAvailable != null) updateData['is_available'] = isAvailable;

      final response = await _supabase
          .from('buses')
          .update(updateData)
          .eq('id', busId)
          .select()
          .single();

      return response;
    } catch (e) {
      print('Error updating bus: $e');
      throw Exception('Failed to update bus: ${e.toString()}');
    }
  }

  /// Delete bus (admin only)
  static Future<void> deleteBus(String busId) async {
    try {
      await _supabase.from('buses').delete().eq('id', busId);
    } catch (e) {
      print('Error deleting bus: $e');
      throw Exception('Failed to delete bus: ${e.toString()}');
    }
  }

  /// Subscribe to real-time updates for active buses
  static RealtimeChannel subscribeToActiveBuses({
    required Function(List<Map<String, dynamic>>) onUpdate,
  }) {
    final channel = _supabase.channel('active_buses_${DateTime.now().millisecondsSinceEpoch}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'drivers',
        callback: (payload) async {
          print('Driver change detected: ${payload.eventType}');
          print('Payload: ${payload.newRecord}');
          
          // **INCREASE DELAY for better database consistency**
          await Future.delayed(const Duration(milliseconds: 500)); // Change 100ms to 500ms
          
          // Refetch active buses
          try {
            final buses = await getActiveBuses();
            print('Refetched ${buses.length} active buses');
            onUpdate(buses);
          } catch (e) {
            print('Error refetching buses: $e');
          }
        },
      )
      ..subscribe();

    return channel;
  }

  /// Get available buses - ADMIN ONLY
  /// Returns buses that are not currently assigned to any driver
  static Future<List<Map<String, dynamic>>> getAvailableBuses() async {
    try {
      final response = await _supabase
          .from('buses')
          .select('*')
          .eq('status', 'inactive')
          .eq('is_available', true);

      // Filter out buses that already have a driver assigned
      final drivers = await _supabase
          .from('drivers')
          .select('assigned_bus_id')
          .not('assigned_bus_id', 'is', null);

      final assignedBusIds = drivers
          .map((d) => d['assigned_bus_id'])
          .where((id) => id != null)
          .toSet();

      final availableBuses = (response as List)
          .where((bus) => !assignedBusIds.contains(bus['id']))
          .toList();

      return List<Map<String, dynamic>>.from(availableBuses);
    } catch (e) {
      print('Error fetching available buses: $e');
      return [];
    }
  }

  /// Assign bus to driver - ADMIN ONLY
  /// This is called by admin to assign a bus to a driver
  static Future<void> assignBusToDriver({
    required String driverId,
    required String busId,
  }) async {
    try {
      // Update driver with assigned bus
      await _supabase
          .from('drivers')
          .update({'assigned_bus_id': busId})
          .eq('id', driverId);

      print('Bus $busId assigned to driver $driverId');
    } catch (e) {
      print('Error assigning bus: $e');
      throw Exception('Failed to assign bus: ${e.toString()}');
    }
  }

  /// Unassign bus from driver - ADMIN ONLY
  /// This is called by admin to remove a bus assignment from a driver
  static Future<void> unassignBusFromDriver(String driverId) async {
    try {
      // Get current driver info
      final driver = await _supabase
          .from('drivers')
          .select('assigned_bus_id')
          .eq('id', driverId)
          .single();

      final busId = driver['assigned_bus_id'];

      if (busId != null) {
        // Update bus status to inactive
        await _supabase
            .from('buses')
            .update({'status': 'inactive'})
            .eq('id', busId);
      }

      // Remove assignment from driver and ensure they're off duty
      await _supabase
          .from('drivers')
          .update({
            'assigned_bus_id': null,
            'is_on_duty': false,
            'current_latitude': null,
            'current_longitude': null,
          })
          .eq('id', driverId);

      print('Bus unassigned from driver $driverId');
    } catch (e) {
      print('Error unassigning bus: $e');
      throw Exception('Failed to unassign bus: ${e.toString()}');
    }
  }

  /// Get bus statistics (for admin dashboard)
  static Future<Map<String, int>> getBusStatistics() async {
    try {
      // Fetch all bus records (only need status column)
      final allBuses = await _supabase.from('buses').select('status');

      final int total = allBuses.length;
      final int active = allBuses.where((bus) => bus['status'] == 'active').length;
      final int inactive =
          allBuses.where((bus) => bus['status'] == 'inactive').length;
      final int maintenance =
          allBuses.where((bus) => bus['status'] == 'maintenance').length;

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'maintenance': maintenance,
      };
    } catch (e) {
      print('Error fetching bus statistics: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'maintenance': 0,
      };
    }
  }

  /// Get all buses with assigned driver info
  static Future<List<Map<String, dynamic>>> getAllBusesWithDrivers() async {
    try {
      final response = await _supabase
          .from('buses')
          .select('''
            *,
            drivers!drivers_assigned_bus_id_fkey(
              id,
              users!inner(full_name)
            )
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching buses with drivers: $e');
      throw Exception('Failed to fetch buses: ${e.toString()}');
    }
  }

  /// Get buses assigned to a specific driver
  /// Used by drivers to see their assigned bus
  static Future<Map<String, dynamic>?> getDriverAssignedBus(
      String driverId) async {
    try {
      final driver = await _supabase
          .from('drivers')
          .select('assigned_bus_id')
          .eq('id', driverId)
          .single();

      final busId = driver['assigned_bus_id'];

      if (busId == null) {
        print('No bus assigned to driver $driverId');
        return null;
      }

      final bus = await getBusById(busId);
      return bus;
    } catch (e) {
      print('Error fetching assigned bus: $e');
      return null;
    }
  }
}