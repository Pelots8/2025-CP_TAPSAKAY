import 'package:flutter/material.dart';
import '../services/hardware_service.dart';

class HardwareStatusWidget extends StatefulWidget {
  const HardwareStatusWidget({super.key});

  @override
  State<HardwareStatusWidget> createState() => _HardwareStatusWidgetState();
}

class _HardwareStatusWidgetState extends State<HardwareStatusWidget> {
  final HardwareService _hardwareService = HardwareService();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initializeHardware();
  }

  @override
  void dispose() {
    _hardwareService.disconnect();
    super.dispose();
  }

  Future<void> _initializeHardware() async {
    setState(() => _isConnecting = true);
    
    // Auto-discover and connect
    await _hardwareService.initialize();
    
    if (mounted) {
      setState(() => _isConnecting = false);
    }
  }
  
  Future<void> _reconnect() async {
    setState(() => _isConnecting = true);
    
    // Force re-discovery
    await _hardwareService.autoDiscover();
    
    if (mounted) {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _hardwareService.gpsStream,
      builder: (context, snapshot) {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _hardwareService.isConnected 
                          ? Icons.wifi
                          : Icons.wifi_off,
                      color: _hardwareService.isConnected 
                          ? Colors.green 
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hardware Module',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isConnecting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        onPressed: _reconnect,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Reconnect',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hardwareService.isConnected 
                      ? '${_hardwareService.connectionStatus} (${_hardwareService.connectedIP})'
                      : _hardwareService.connectionStatus,
                  style: TextStyle(
                    color: _hardwareService.isConnected 
                        ? Colors.green 
                        : Colors.red,
                    ),
                ),
                if (_hardwareService.isConnected) ...[
                  const Divider(),
                  const Text(
                    'GPS Data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.hasData) ...[
                    _buildGPSRow('Latitude', _hardwareService.currentLatitude?.toString()),
                    _buildGPSRow('Longitude', _hardwareService.currentLongitude?.toString()),
                    _buildGPSRow('Speed', '${_hardwareService.currentSpeed?.toStringAsFixed(1)} km/h'),
                    _buildGPSRow('Satellites', '${_hardwareService.satellites}'),
                    if (_hardwareService.isMockData)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Mock Data',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ] else
                    const Text('Waiting for GPS data...'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGPSRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value ?? 'N/A'),
        ],
      ),
    );
  }
}
