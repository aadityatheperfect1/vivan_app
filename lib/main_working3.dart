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
      home: MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final UsbConnectionManager _connectionManager = UsbConnectionManager();

  @override
  void initState() {
    super.initState();
    _connectionManager.init();
  }

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VIVAN Serial Monitor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(connectionManager: _connectionManager),
          SelfVehiclePage(connectionManager: _connectionManager),
          DevelopersPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Self Vehicle',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.code),
            label: 'Developers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class UsbConnectionManager {
  UsbPort? _port;
  UsbDevice? _device;
  String _status = "Disconnected";
  List<UsbDevice> _availableDevices = [];
  List<Map<String, dynamic>> vehicleInformation = [];
  Map<String, dynamic> selfVehicle = {
    'latitude': -1,
    'longitude': -1,
    'speed': -1,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  StreamController<String> _statusController = StreamController.broadcast();
  StreamController<List<Map<String, dynamic>>> _vehiclesController = StreamController.broadcast();
  StreamController<Map<String, dynamic>> _selfVehicleController = StreamController.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<List<Map<String, dynamic>>> get vehiclesStream => _vehiclesController.stream;
  Stream<Map<String, dynamic>> get selfVehicleStream => _selfVehicleController.stream;

  void init() {
    _getAvailableDevices();
    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_DETACHED && _device != null) {
        if (event.device?.deviceId == _device?.deviceId) {
          _disconnect();
        }
      }
      _getAvailableDevices();
    });
  }

  Future<void> _getAvailableDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (_device != null && !devices.any((d) => d.deviceId == _device?.deviceId)) {
      await _disconnect();
    }
    _availableDevices = devices;
    _statusController.add(_status);
  }

  List<UsbDevice> get availableDevices => _availableDevices;
  UsbDevice? get connectedDevice => _device;
  String get status => _status;
  List<Map<String, dynamic>> get vehicleInfo => vehicleInformation;
  Map<String, dynamic> get selfVehicleInfo => selfVehicle;

  Future<void> connectToDevice(UsbDevice device) async {
    await _disconnect();

    try {
      _port = await device.create();
      if (!(await _port!.open())) {
        _status = "Failed to open port";
        _statusController.add(_status);
        return;
      }

      _device = device;
      await _port!.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      final transaction = Transaction.stringTerminated(
        _port!.inputStream!.asBroadcastStream(),
        Uint8List.fromList([13, 10]),
      );

      transaction.stream.listen((String line) {
        _processSerialData(line);
      }, onDone: () {
        _disconnect();
      });

      _status = "Connected to ${device.productName ?? 'device'}";
      selfVehicle['status'] = 'Connected';
      _statusController.add(_status);
      _selfVehicleController.add(selfVehicle);
    } catch (e) {
      _status = "Connection error: ${e.toString()}";
      _statusController.add(_status);
    }
  }

  void _processSerialData(String line) {
    try {
      final dynamic decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic> && decoded['type'] == "Packet") {
        _updateVehicleInformation(decoded);
        _updateSelfVehicleInformation(decoded);
      }
    } catch (e) {
      debugPrint("Error parsing data: $e");
    }
  }

  void _updateVehicleInformation(Map<String, dynamic> data) {
    final vehicleId = data['remote_vehicle']?.toString();
    if (vehicleId == null) return;

    final existingIndex = vehicleInformation.indexWhere((v) => v['id'] == vehicleId);
    if (existingIndex >= 0) {
      vehicleInformation[existingIndex] = {
        'id': vehicleId,
        'latitude': data['remote_latitude'],
        'longitude': data['remote_longitude'],
        'speed': data['remote_speed'],
        'status': data['remote_status'],
        'lastReceivedTime': data['remote_time'],
        'mac': data['remote_mac'],
      };
    } else {
      vehicleInformation.add({
        'id': vehicleId,
        'latitude': data['remote_latitude'],
        'longitude': data['remote_longitude'],
        'speed': data['remote_speed'],
        'status': data['remote_status'],
        'lastReceivedTime': data['remote_time'],
        'mac': data['remote_mac'],
      });
    }
    _vehiclesController.add(vehicleInformation);
  }

  void _updateSelfVehicleInformation(Map<String, dynamic> data) {
    selfVehicle = {
      'latitude': data['self_latitude'] ?? selfVehicle['latitude'],
      'longitude': data['self_longitude'] ?? selfVehicle['longitude'],
      'speed': data['self_speed'] ?? selfVehicle['speed'],
      'vehicle': data['self_vehicle'] ?? selfVehicle['vehicle'],
      'time': data['self_time'] ?? selfVehicle['time'],
      'status': _status == "Disconnected" ? 'Disconnected' : 'Connected',
    };
    _selfVehicleController.add(selfVehicle);
  }

  Future<void> disconnect() async {
    await _disconnect();
  }

  Future<void> _disconnect() async {
    await _port?.close();
    _port = null;
    _device = null;
    _status = "Disconnected";
    selfVehicle['status'] = 'Disconnected';
    _statusController.add(_status);
    _selfVehicleController.add(selfVehicle);
  }

  void dispose() {
    _disconnect();
    _statusController.close();
    _vehiclesController.close();
    _selfVehicleController.close();
  }
}

class HomePage extends StatefulWidget {
  final UsbConnectionManager? connectionManager;

  const HomePage({Key? key, this.connectionManager}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late StreamSubscription<String> _statusSubscription;
  late StreamSubscription<List<Map<String, dynamic>>> _vehiclesSubscription;
  String _status = "Disconnected";
  List<Map<String, dynamic>> vehicleInformation = [];

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget.connectionManager!.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });
    _vehiclesSubscription = widget.connectionManager!.vehiclesStream.listen((vehicles) {
      setState(() {
        vehicleInformation = vehicles;
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    _vehiclesSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (widget.connectionManager!.connectedDevice != null) ...[
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.usb_off),
                    label: Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.connectionManager!.disconnect,
                  ),
                ],
              ],
            ),
          ),
        ),

        if (widget.connectionManager!.connectedDevice == null)
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
                    itemCount: widget.connectionManager!.availableDevices.length,
                    itemBuilder: (context, index) {
                      final device = widget.connectionManager!.availableDevices[index];
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
                            onPressed: () => widget.connectionManager!.connectToDevice(device),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        if (widget.connectionManager!.connectedDevice != null)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
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
                              if (vehicle['mac'] != null)
                                _buildInfoRow('MAC:', vehicle['mac']),
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

class SelfVehiclePage extends StatefulWidget {
  final UsbConnectionManager? connectionManager;

  const SelfVehiclePage({Key? key, this.connectionManager}) : super(key: key);

  @override
  _SelfVehiclePageState createState() => _SelfVehiclePageState();
}

class _SelfVehiclePageState extends State<SelfVehiclePage> {
  late StreamSubscription<Map<String, dynamic>> _selfVehicleSubscription;
  late StreamSubscription<String> _statusSubscription;
  Map<String, dynamic> selfVehicle = {
    'latitude': -1,
    'longitude': -1,
    'speed': -1,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  @override
  void initState() {
    super.initState();
    _selfVehicleSubscription = widget.connectionManager!.selfVehicleStream.listen((vehicle) {
      setState(() {
        selfVehicle = vehicle;
      });
    });
    _statusSubscription = widget.connectionManager!.statusStream.listen((status) {
      setState(() {
        selfVehicle['status'] = status == "Disconnected" ? 'Disconnected' : 'Connected';
      });
    });
  }

  @override
  void dispose() {
    _selfVehicleSubscription.cancel();
    _statusSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.indigo),
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
              _buildInfoRow('Status:', selfVehicle['status'],
                  isGood: selfVehicle['status'] == 'Connected'),
              _buildInfoRow('Speed:', '${selfVehicle['speed']} km/h'),
              _buildInfoRow('Latitude:', '${selfVehicle['latitude']}'),
              _buildInfoRow('Longitude:', '${selfVehicle['longitude']}'),
              _buildInfoRow('Last Update:', selfVehicle['time']),
            ],
          ),
        ),
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
}

class DevelopersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Developers Page',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Settings Page',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}