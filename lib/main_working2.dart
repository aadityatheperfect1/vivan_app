import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(SerialMonitorApp());

class SerialMonitorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIVAN Serial Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.indigo,
          secondary: Colors.amber,
          surface: Colors.grey[50]!,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(8),
        ),
      ),
      home: SerialMonitorPage(),
    );
  }
}

class SerialMonitorPage extends StatefulWidget {
  @override
  _SerialMonitorPageState createState() => _SerialMonitorPageState();
}

class _SerialMonitorPageState extends State<SerialMonitorPage> {
  UsbPort? _port;
  UsbDevice? _device;
  String _status = "Disconnected";
  List<String> _serialData = [];
  List<UsbDevice> _availableDevices = [];
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;

  List<Map<String, dynamic>> vehicleInformation = [];
  Map<String, dynamic> selfVehicle = {
    'latitude': -1,
    'longitude': -1,
    'speed': -1,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
  };

  @override
  void initState() {
    super.initState();
    _getAvailableDevices();
    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      _getAvailableDevices();
    });
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _getAvailableDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    setState(() {
      _availableDevices = devices;
    });
  }

  Future<void> _connectToDevice(UsbDevice device) async {
    await _disconnect();

    try {
      _port = await device.create();
      if (!(await _port!.open())) {
        setState(() => _status = "Failed to open port");
        return;
      }

      _device = device;
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _transaction = Transaction.stringTerminated(
        _port!.inputStream!.asBroadcastStream(),
        Uint8List.fromList([13, 10]),
      );

      _subscription = _transaction!.stream.listen((String line) {
        _processSerialData(line);
      });

      setState(() {
        _status = "Connected to ${device.productName ?? 'device'}";
      });
    } catch (e) {
      setState(() => _status = "Connection error: ${e.toString()}");
    }
  }

  void _processSerialData(String line) {
    setState(() {
      _serialData.add(line);
      if (_serialData.length > 100) {
        _serialData.removeAt(0);
      }
    });

    try {
      final dynamic decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == "Packet") {
          // Always update vehicle ID, even if lat/lon is -1
          selfVehicle['vehicle'] = decoded['self_vehicle'];
          selfVehicle['time'] = decoded['self_time'];

          // Update other fields only if GPS data is available
          if (decoded['self_latitude'] != -1) {
            selfVehicle['latitude'] = decoded['self_latitude'];
            selfVehicle['longitude'] = decoded['self_longitude'];
            selfVehicle['speed'] = decoded['self_speed'];
          }
          _updateVehicleInformation(decoded);
        }
      }
    } catch (e) {
      debugPrint("Error parsing data: $e");
    }
  }

  void _updateVehicleInformation(Map<String, dynamic> data) {
    final vehicleId = data['remote_vehicle']?.toString();
    if (vehicleId == null) return;

    setState(() {
      final existingIndex = vehicleInformation.indexWhere((v) => v['id'] == vehicleId);
      if (existingIndex >= 0) {
        vehicleInformation[existingIndex] = {
          'id': vehicleId,
          'latitude': data['remote_latitude'],
          'longitude': data['remote_longitude'],
          'speed': data['remote_speed'],
          'status': data['remote_status'],
          'lastReceivedTime': data['remote_time'],
        };
      } else {
        vehicleInformation.add({
          'id': vehicleId,
          'latitude': data['remote_latitude'],
          'longitude': data['remote_longitude'],
          'speed': data['remote_speed'],
          'status': data['remote_status'],
          'lastReceivedTime': data['remote_time'],
        });
      }
    });
  }

  Future<void> _disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    _transaction?.dispose();
    _transaction = null;
    await _port?.close();
    _port = null;
    _device = null;
    setState(() => _status = "Disconnected");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIVAN Serial Monitor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Connection Status Card - Updated version
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Updated status row with wrapping
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Connection Status:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _status == "Disconnected" ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_device != null) ...[
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.usb_off),
                      label: Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _disconnect,
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_device == null)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Available USB Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = _availableDevices[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.usb, color: Colors.indigo),
                            title: Text(
                              device.productName ?? 'Unknown Device',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              device.manufacturerName ?? 'Unknown Manufacturer',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: ElevatedButton.icon(
                              icon: Icon(Icons.link),
                              label: Text('Connect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _connectToDevice(device),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (_device != null)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Self Vehicle Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.directions_car,
                                    color: Colors.indigo),
                                SizedBox(width: 8),
                                Text(
                                  'Self Vehicle',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            Divider(),
                            _buildInfoRow('ID:', selfVehicle['vehicle']),
                            _buildInfoRow('Status:', 'Connected',
                                isGood: true),
                            _buildInfoRow(
                                'Speed:', '${selfVehicle['speed']} km/h'),
                            _buildInfoRow(
                                'Latitude:', '${selfVehicle['latitude']}'),
                            _buildInfoRow(
                                'Longitude:', '${selfVehicle['longitude']}'),
                            _buildInfoRow(
                                'Last Update:', selfVehicle['time']),
                          ],
                        ),
                      ),
                    ),

                    // Nearby Vehicles Section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.group, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text(
                            'Nearby Vehicles (${vehicleInformation.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nearby Vehicles List
                    if (vehicleInformation.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No nearby vehicles detected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...vehicleInformation.map((vehicle) {
                        return Card(
                          margin: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.directions_car,
                                        color: Colors.indigo, size: 30),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Vehicle ${vehicle['id']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          'Status: ${vehicle['status']}',
                                          style: TextStyle(
                                            color: _getStatusColor(vehicle['status']),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                _buildInfoRow('Speed:',
                                    '${vehicle['speed']} km/h'),
                                _buildInfoRow('Position:',
                                    'Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}'),
                                _buildInfoRow('Last Update:',
                                    vehicle['lastReceivedTime']),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isGood = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isGood ? Colors.green : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}