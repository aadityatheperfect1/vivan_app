import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';
// import 'package:vivan_app/voicechat.dart';
import 'package:vivan_app/voicestate.dart';

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
    'latitude': -1.0,
    'longitude': -1.0,
    'speed': -1.0,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  @override
  void initState() {
    super.initState();
    _selfVehicleSubscription = widget.connectionManager!.selfVehicleStream
        .listen((vehicle) {
          setState(() => selfVehicle = vehicle);
        });
    _statusSubscription = widget.connectionManager!.statusStream.listen((
      status,
    ) {
      setState(
        () =>
            selfVehicle['status'] =
                status == "Disconnected" ? 'Disconnected' : 'Connected',
      );
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
              _buildInfoRow(
                'Status:',
                selfVehicle['status'],
                isGood: selfVehicle['status'] == 'Connected',
              ),
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
              style: TextStyle(color: isGood ? Colors.green : Colors.black),
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
      child: Text('Developers1 Page', style: TextStyle(fontSize: 24)),
    );
  }
}

// class VoiceChat extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Text('Voice Chat Page', style: TextStyle(fontSize: 24)),
//     );
//   }
// }

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Page', style: TextStyle(fontSize: 24)));
  }
}

class ConnectedView extends StatefulWidget {
  final Map<String, dynamic> connectedVehicle;
  final UsbConnectionManager connectionManager;

  const ConnectedView({
    Key? key,
    required this.connectedVehicle,
    required this.connectionManager,
  }) : super(key: key);

  @override
  _ConnectedViewState createState() => _ConnectedViewState();
}

class _ConnectedViewState extends State<ConnectedView> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late StreamSubscription<Map<String, dynamic>> _chatMessageSubscription;

  @override
  void initState() {
    super.initState();
    _chatMessageSubscription = widget.connectionManager.chatMessageStream
        .listen((message) {
          if (message['mac'] == widget.connectedVehicle['mac']) {
            setState(() {
              _messages.add({
                'message': message['message'],
                'isMe': false,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            });
          }
        });
  }

  @override
  void dispose() {
    _chatMessageSubscription.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    // Send the message
    widget.connectionManager.sendChatMessage(
      _messageController.text,
      widget.connectedVehicle['mac'],
    );

    // Add to local messages immediately
    setState(() {
      _messages.add({
        'message': _messageController.text,
        'isMe': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // Clear the input field
    _messageController.clear();
  }

  void _disconnect() {
    widget.connectionManager.sendChatResponse(
      "Disconnect",
      widget.connectedVehicle['mac'],
      widget.connectionManager.selfVehicle['vehicle'],
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: EdgeInsets.all(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CONNECTED TO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Icon(
                      Icons.signal_wifi_statusbar_4_bar_rounded,
                      color: Colors.green,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildConnectionInfoRow(
                  'Vehicle:',
                  widget.connectedVehicle['vehicle'],
                ),
                _buildConnectionInfoRow(
                  'MAC Address:',
                  widget.connectedVehicle['mac'],
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _disconnect,
                  child: Text('DISCONNECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50]),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: false,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                SizedBox(height: 8),
                _buildMessageInput(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
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
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] == true;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue[100] : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: isMe ? Radius.circular(12) : Radius.circular(0),
                bottomRight: isMe ? Radius.circular(0) : Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe
                      ? 'You'
                      : widget.connectedVehicle['vehicle'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isMe ? Colors.blue[800] : Colors.indigo,
                  ),
                ),
                SizedBox(height: 4),
                Text(message['message'], style: TextStyle(fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  _formatTimestamp(message['timestamp']),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.indigo,
          child: IconButton(
            icon: Icon(Icons.send, color: Colors.white),
            onPressed: _sendMessage,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final UsbConnectionManager _connectionManager = UsbConnectionManager();

  late StreamSubscription<Map<String, dynamic>> _requestSubscription;

  Map<String, dynamic>? _connectedVehicle;

  late StreamSubscription<Map<String, dynamic>> _chatResponseSubscription;

  @override
  void initState() {
    super.initState();
    _connectionManager.init();
    _setupRequestListener();
    _setupChatResponseListener();
  }

  void _setupChatResponseListener() {
    _chatResponseSubscription = _connectionManager.chatResponseStream.listen((
      response,
    ) {
      if (response['response'] == 'Accepted') {
        setState(() {
          _connectedVehicle = {
            'vehicle': response['vehicle'] ?? 'Unknown',
            'mac': response['mac'],
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection accepted by ${response['mac']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection rejected by ${response['mac']}')),
        );
      }
    });
  }

  void _setupRequestListener() {
    _requestSubscription = _connectionManager.requestStream.listen((request) {
      _showConnectionRequestDialog(request);

      print(request);
    });
  }

  void _showConnectionRequestDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Connection Request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vehicle ${request['vehicle']} wants to connect!'),
                SizedBox(height: 8),
                Text('MAC: ${request['mac']}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text('REJECT'),
                onPressed: () {
                  _connectionManager.sendChatResponse(
                    "Rejected",
                    request['mac'],
                    _connectionManager.selfVehicle['vehicle'],
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connection request rejected')),
                  );
                },
              ),
              TextButton(
                child: Text('ACCEPT'),
                onPressed: () {
                  _connectionManager.sendChatResponse(
                    "Accepted",
                    request['mac'],
                    _connectionManager.selfVehicle['vehicle'],
                  );
                  setState(() {
                    _connectedVehicle = {
                      'vehicle': request['vehicle'],
                      'mac': request['mac'],
                    };
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _chatResponseSubscription.cancel();
    _requestSubscription.cancel();
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VIVAN Serial Monitor')),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Modified HomePage to show either connected view or normal view
          _connectedVehicle != null
              ? ConnectedView(
                connectedVehicle: _connectedVehicle!,
                connectionManager: _connectionManager,
              )
              : HomePage(connectionManager: _connectionManager),
          VoiceState(
            usbOldConnection: _connectionManager,
            connectedVehicle: _connectedVehicle,
          ),
          SelfVehiclePage(connectionManager: _connectionManager),
          DevelopersPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_phone),
            label: 'Voice Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Self Vehicle',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Developers'),
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
    'latitude': -1.0,
    'longitude': -1.0,
    'speed': -1.0,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  final StreamController<String> _statusController =
      StreamController.broadcast();
  final StreamController<List<Map<String, dynamic>>> _vehiclesController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _selfVehicleController =
      StreamController.broadcast();

  // Add these new stream controllers
  final StreamController<Map<String, dynamic>> _chatResponseController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get chatResponseStream =>
      _chatResponseController.stream;
  Stream<Map<String, dynamic>> get chatMessageStream =>
      _chatMessageController.stream;

  Stream<String> get statusStream => _statusController.stream;
  Stream<List<Map<String, dynamic>>> get vehiclesStream =>
      _vehiclesController.stream;
  Stream<Map<String, dynamic>> get selfVehicleStream =>
      _selfVehicleController.stream;

  // Add this new stream controller for connection requests
  final StreamController<Map<String, dynamic>> _requestController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get requestStream => _requestController.stream;

  Future<void> sendChatResponse(
    String response,
    String mac,
    String vehicle,
  ) async {
    if (_port == null) return;

    try {
      final payload = {
        "type": "ChatResponse",
        "response": response,
        "mac": mac,
        "vehicle": vehicle,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };

      final message = '${jsonEncode(payload)}\n';
      await _port!.write(Uint8List.fromList(message.codeUnits));
    } catch (e) {
      debugPrint("Error sending chat response: $e");
    }
  }

  Future<void> sendChatMessage(String message, String mac) async {
    if (_port == null) return;

    try {
      final payload = {
        "type": "ChatMessage",
        "message": message, // Changed from 'msg' to 'message' to match Python
        "mac": mac,
      };

      final serializedMessage = '${jsonEncode(payload)}\n';
      await _port!.write(Uint8List.fromList(serializedMessage.codeUnits));
    } catch (e) {
      debugPrint("Error sending chat message: $e");
    }
  }

  void _processSerialData(String line) {
    print("Received line: $line"); // Debugging line
    try {
      final dynamic decoded = jsonDecode(line);

      if (decoded is Map<String, dynamic>) {
        switch (decoded['type']) {
          case "Packet":
            _updateVehicleInformation(decoded);
            _updateSelfVehicleInformation(decoded);
            break;
          case "ChatRequest":
            _requestController.add(decoded);
            break;
          case "ChatResponse":
            _chatResponseController.add(decoded);
            break;
          case "ChatMessage":
            print("Chat message received: ${decoded['msg']}"); // Debugging line
            // Ensure the message has the expected format
            if (decoded['msg'] != null && decoded['mac'] != null) {
              _chatMessageController.add({
                'message': decoded['msg'],
                'mac': decoded['mac'],
              });
            }
            break;
          default:
          // debugPrint("Unknown message type: ${decoded['type']}");
        }
      }
    } catch (e) {
      // debugPrint("Error parsing data: $e");
    }
  }

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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _getAvailableDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (_device != null &&
        !devices.any((d) => d.deviceId == _device?.deviceId)) {
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

      transaction.stream.listen(
        (String line) {
          _processSerialData(line);
        },
        onDone: () {
          _disconnect();
        },
      );

      _status = "Connected to ${device.productName ?? 'device'}";
      selfVehicle['status'] = 'Connected';
      _statusController.add(_status);
      _selfVehicleController.add(selfVehicle);
    } catch (e) {
      _status = "Connection error: ${e.toString()}";
      _statusController.add(_status);
    }
  }

  // void _processSerialData(String line) {
  //   try {
  //     final dynamic decoded = jsonDecode(line);
  //     if (decoded is Map<String, dynamic> && decoded['type'] == "Packet") {
  //       _updateVehicleInformation(decoded);
  //       _updateSelfVehicleInformation(decoded);
  //     }
  //   } catch (e) {
  //     debugPrint("Error parsing data: $e");
  //   }
  // }

  void _updateVehicleInformation(Map<String, dynamic> data) {
    final vehicleId = data['remote_vehicle']?.toString();
    if (vehicleId == null) return;

    final existingIndex = vehicleInformation.indexWhere(
      (v) => v['id'] == vehicleId,
    );
    if (existingIndex >= 0) {
      vehicleInformation[existingIndex] = {
        'id': vehicleId,
        'latitude': _toDouble(data['remote_latitude']),
        'longitude': _toDouble(data['remote_longitude']),
        'speed': _toDouble(data['remote_speed']),
        'status': data['remote_status']?.toString(),
        'lastReceivedTime': data['remote_time']?.toString(),
        'mac': data['remote_mac']?.toString(),
      };
    } else {
      vehicleInformation.add({
        'id': vehicleId,
        'latitude': _toDouble(data['remote_latitude']),
        'longitude': _toDouble(data['remote_longitude']),
        'speed': _toDouble(data['remote_speed']),
        'status': data['remote_status']?.toString(),
        'lastReceivedTime': data['remote_time']?.toString(),
        'mac': data['remote_mac']?.toString(),
      });
    }
    _vehiclesController.add(vehicleInformation);
  }

  void _updateSelfVehicleInformation(Map<String, dynamic> data) {
    selfVehicle = {
      'latitude': _toDouble(data['self_latitude']) ?? selfVehicle['latitude'],
      'longitude':
          _toDouble(data['self_longitude']) ?? selfVehicle['longitude'],
      'speed': _toDouble(data['self_speed']) ?? selfVehicle['speed'],
      'vehicle': data['self_vehicle']?.toString() ?? selfVehicle['vehicle'],
      'time': data['self_time']?.toString() ?? selfVehicle['time'],
      'status': _status == "Disconnected" ? 'Disconnected' : 'Connected',
    };
    _selfVehicleController.add(selfVehicle);
  }

  Future<void> disconnect() async => await _disconnect();

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
    _requestController.close(); // Added new line
    _chatResponseController.close();
    _chatMessageController.close();
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
  late StreamSubscription<Map<String, dynamic>> _selfVehicleSubscription;

  late StreamSubscription<Map<String, dynamic>> _chatResponseSubscription;

  String _status = "Disconnected";
  List<Map<String, dynamic>> vehicleInformation = [];
  Map<String, dynamic> selfVehicle = {
    'latitude': -1.0,
    'longitude': -1.0,
    'speed': -1.0,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  // Add this new method to handle the connection initiation
  // Updated method to send JSON-formatted request
  void _initiateConnection(Map<String, dynamic> vehicle) {
    if (widget.connectionManager?._port == null) return;

    try {
      final payload = {
        "type": "Request",
        "vehicle": vehicle['vehicle'] ?? vehicle['id'] ?? 'Unknown',
        "mac": vehicle['mac'] ?? 'Unknown',
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };

      final message = '${jsonEncode(payload)}\n';
      widget.connectionManager?._port?.write(
        Uint8List.fromList(message.codeUnits),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${payload['vehicle']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: ${e.toString()}')),
      );
    }
  }

  void _handleChatResponse(Map<String, dynamic> response) {
    if (response['response'] == 'Accepted') {
      // This device initiated the request that was accepted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection accepted by ${response['mac']}')),
      );
      // You might want to update the connection state here too
    } else if (response['response'] == 'Rejected') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection rejected by ${response['mac']}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget.connectionManager!.statusStream.listen(
      (status) => setState(() => _status = status),
    );
    _vehiclesSubscription = widget.connectionManager!.vehiclesStream.listen(
      (vehicles) => setState(() => vehicleInformation = vehicles),
    );
    _selfVehicleSubscription = widget.connectionManager!.selfVehicleStream
        .listen((vehicle) => setState(() => selfVehicle = vehicle));
    _chatResponseSubscription = widget.connectionManager!.requestStream
        .where((data) => data['type'] == 'ChatResponse')
        .listen(_handleChatResponse);
  }

  @override
  void dispose() {
    _chatResponseSubscription.cancel();
    _statusSubscription.cancel();
    _vehiclesSubscription.cancel();
    _selfVehicleSubscription.cancel();
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _status == "Disconnected"
                                  ? Colors.red
                                  : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _status,
                          style: TextStyle(color: Colors.white, fontSize: 12),
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
          _buildDeviceList()
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 250,
                    child: RadarView(
                      selfLatitude: selfVehicle['latitude'],
                      selfLongitude: selfVehicle['longitude'],
                      vehicles: vehicleInformation,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
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
                      final distance = calculateHaversine(
                        8.6279986,
                        77.0339556,
                        vehicle['latitude'],
                        vehicle['longitude'],
                      );
                      final angle = calculateAngle(
                        8.6279986,
                        77.0339556,
                        vehicle['latitude'],
                        vehicle['longitude'],
                      );

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    color: Colors.indigo,
                                    size: 30,
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vehicle ${vehicle['id']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${vehicle['status']}',
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            vehicle['status'],
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              _buildInfoRow(
                                'Distance:',
                                '${distance.toStringAsFixed(1)} m',
                              ),
                              _buildInfoRow(
                                'Direction:',
                                '${angle.toStringAsFixed(1)}°',
                              ),
                              _buildInfoRow(
                                'Speed:',
                                '${vehicle['speed']} km/h',
                              ),
                              _buildInfoRow(
                                'Position:',
                                'Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}',
                              ),
                              _buildInfoRow(
                                'Last Update:',
                                vehicle['lastReceivedTime'],
                              ),
                              if (vehicle['mac'] != null)
                                _buildInfoRow('MAC:', vehicle['mac']),

                              // Add the new connection button here
                              SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: Icon(
                                  Icons.connect_without_contact,
                                  size: 16,
                                ),
                                label: Text('Initiate Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 36),
                                ),
                                onPressed: () => _initiateConnection(vehicle),
                              ),
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

  Widget _buildDeviceList() {
    return Expanded(
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
                final device =
                    widget.connectionManager!.availableDevices[index];
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
                      onPressed:
                          () =>
                              widget.connectionManager!.connectToDevice(device),
                    ),
                  ),
                );
              },
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
              style: TextStyle(color: isGood ? Colors.green : Colors.black),
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

class RadarView extends StatelessWidget {
  final double selfLatitude;
  final double selfLongitude;
  final List<Map<String, dynamic>> vehicles;

  const RadarView({
    Key? key,
    required this.selfLatitude,
    required this.selfLongitude,
    required this.vehicles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          border: Border.all(color: Colors.indigo, width: 2),
        ),
        child: Stack(
          children: [
            // Radar circles
            ...List.generate(3, (index) {
              final radius = (index + 1) * 50.0;
              return Positioned(
                left: 100 - radius,
                top: 100 - radius,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: Colors.indigo.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
              );
            }),

            // Radar cross lines
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.indigo.withOpacity(0.3),
                    width: 1,
                  ),
                  left: BorderSide(
                    color: Colors.indigo.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
            ),

            // Vehicle indicators
            ...vehicles.map((vehicle) {
              final vehicleLat = _toDouble(vehicle['latitude']);
              final vehicleLon = _toDouble(vehicle['longitude']);
              final selfLat = _toDouble(selfLatitude) ?? 0;
              final selfLon = _toDouble(selfLongitude) ?? 0;

              if (vehicleLat == null ||
                  vehicleLon == null ||
                  vehicleLat == 0 ||
                  vehicleLon == 0 ||
                  selfLat == 0 ||
                  selfLon == 0) {
                return SizedBox.shrink();
              }

              final distance = calculateHaversine(
                8.6279986,
                // selfLat,
                77.0339556,
                // selfLon
                vehicleLat,
                vehicleLon,
              );

              final angle = calculateAngle(
                8.6279986,
                // selfLat,
                77.0339556,
                // selfLon
                vehicleLat,
                vehicleLon,
              );

              // Scale distance to fit in radar (max 150m shown)
              final scaledDistance = min(distance, 150) / 150 * 100;

              // Convert polar to cartesian coordinates
              final radian = angle * pi / 180;
              final x = 100 + scaledDistance * cos(radian);
              final y = 100 + scaledDistance * sin(radian);

              return Positioned(
                left: x - 8,
                top: y - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(vehicle['status']?.toString() ?? ''),
                  ),
                  child: Center(
                    child: Text(
                      vehicle['id']?.toString().substring(0, 1) ?? '?',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              );
            }).toList(),

            // Center indicator (self vehicle)
            Positioned(
              left: 95,
              top: 95,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to safely convert to double
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
        return Colors.blue;
    }
  }
}

// Haversine distance calculation in meters
double calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // Earth radius in meters
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final deltaPhi = (lat2 - lat1) * pi / 180;
  final deltaLambda = (lon2 - lon1) * pi / 180;

  final a =
      sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

// Calculate angle in degrees (0-360) from self to target
double calculateAngle(double lat1, double lon1, double lat2, double lon2) {
  final deltaLon = (lon2 - lon1) * pi / 180;
  final lat1Rad = lat1 * pi / 180;
  final lat2Rad = lat2 * pi / 180;

  final y = sin(deltaLon) * cos(lat2Rad);
  final x =
      cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLon);

  var angle = atan2(y, x) * 180 / pi;
  return (angle + 360) % 360; // Normalize to 0-360
}
