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

  // Vehicle data storage
  List<Map<String, dynamic>> vehicleInformation = [];

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
        Uint8List.fromList([13, 10]), // Line endings: \r\n
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
      if (decoded is Map<String, dynamic> && decoded['type'] == "Packet") {
        _updateVehicleInformation(decoded);
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
        // Update existing vehicle
        vehicleInformation[existingIndex] = {
          'id': vehicleId,
          'latitude': data['remote_latitude'],
          'longitude': data['remote_longitude'],
          'speed': data['remote_speed'],
          'status': data['remote_status'],
          'lastUpdate': DateTime.now(),
        };
      } else {
        // Add new vehicle
        vehicleInformation.add({
          'id': vehicleId,
          'latitude': data['remote_latitude'],
          'longitude': data['remote_longitude'],
          'speed': data['remote_speed'],
          'status': data['remote_status'],
          'lastUpdate': DateTime.now(),
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
      // Status and connection controls
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

    // Device list
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

    // Serial data display
    Expanded(
    child: Container(
    padding: const EdgeInsets.all(8.0),
    decoration: const BoxDecoration(
    border: Border(top: BorderSide(color: Colors.grey)),
    ),
    child: ListView.builder(
    itemCount: _serialData.length,
    itemBuilder: (context, index) {
    return Text(_serialData[index]);
    },
    ),
    ),
    ),

    // Vehicle information display
    Expanded(
    child: Container(
    padding: const EdgeInsets.all(8.0),
    decoration: const BoxDecoration(
    border: Border(top: BorderSide(color: Colors.grey)),
    ),
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
    Text('Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}'),
    ],
    ),
    );
    },
    ),
    ),
    ),
    ]
    ),
    );
  }
}