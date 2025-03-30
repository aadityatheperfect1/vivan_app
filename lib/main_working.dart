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
      theme: ThemeData(primarySwatch: Colors.blue),
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
        title: const Text('VIVAN Serial Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getAvailableDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text('Status: $_status'),
                const SizedBox(height: 10),
                if (_device != null)
                  ElevatedButton(
                    onPressed: _disconnect,
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ),
          if (_device == null)
            Expanded(
              child: ListView.builder(
                itemCount: _availableDevices.length,
                itemBuilder: (context, index) {
                  final device = _availableDevices[index];
                  return ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text(device.productName ?? 'Unknown Device'),
                    subtitle: Text(device.manufacturerName ?? 'Unknown Manufacturer'),
                    trailing: ElevatedButton(
                      onPressed: () => _connectToDevice(device),
                      child: const Text('Connect'),
                    ),
                  );
                },
              ),
            ),
          if (_device != null)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Self Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('ID: ${selfVehicle['vehicle']}'),
                    Text('Status: Connected'),
                    Text('Speed: ${selfVehicle['speed']} km/h'),
                    Text('Latitude: ${selfVehicle['latitude']}'),
                    Text('Longitude: ${selfVehicle['longitude']}'),
                    Text('Last Update: ${selfVehicle['time']}'),
                  ],
                ),
              ),
            ),
          if (_device != null)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey)),
                ),
                child: Column(
                  children: [
                    const Text('Nearby Vehicles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: vehicleInformation.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicleInformation[index];
                          return ListTile(
                            title: Text('Vehicle ${vehicle['id']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${vehicle['status']}'),
                                Text('Speed: ${vehicle['speed']} km/h'),
                                Text('Last Received at: ${vehicle['lastReceivedTime']}'),
                                Text('Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
