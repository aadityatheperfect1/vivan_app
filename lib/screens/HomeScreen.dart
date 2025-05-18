import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vivan_app/UsbConnectionManager.dart';
import 'dart:async';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StreamSubscription<String> _statusSubscription;
  late StreamSubscription<List<Map<String, dynamic>>> _vehiclesSubscription;
  late StreamSubscription<Map<String, dynamic>> _selfVehicleSubscription;
  late StreamSubscription<Map<String, dynamic>> _requestSubscription;
  late StreamSubscription<Map<String, dynamic>> _chatResponseController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    // Initialize the USB connection manager
    usbManager.init();

    _statusSubscription = usbManager.statusStream.listen((status) {
      setState(() {
        print("Status: $status");
      });
    });

    _vehiclesSubscription = usbManager.vehiclesStream.listen((vehicles) {
      setState(() {});
    });

    _selfVehicleSubscription = usbManager.selfVehicleStream.listen((vehicle) {
      setState(() {});
    });

    _requestSubscription = usbManager.requestStream.listen((request) {
      print("Request: $request");
      _showConnectionRequestDialog(request);
    });

    _chatResponseController = usbManager.chatResponseStream.listen((response) {
      print("Chat Response: $response");
      if (response['response'] == "Accepted") {
        usbManager.connectedVehicle?['mac'] = response['mac'];
        usbManager.connectedVehicle?['vehicle'] = response['vehicle'];
        usbManager.connectedVehicle?['status'] = "Connected";
        print("Connection Accepted");
      } else {
        // Handle rejected response
        print("Connection Rejected");
      }
    });
  }

  void _showConnectionRequestDialog(Map<String, dynamic> request) {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

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
                  usbManager.sendChatResponse(
                    "Rejected",
                    request['mac'],
                    usbManager.selfVehicleInfo['vehicle'],
                  );
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: Text('ACCEPT'),
                onPressed: () {
                  usbManager.sendChatResponse(
                    "Accepted",
                    request['mac'],
                    usbManager.selfVehicleInfo['vehicle'],
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    _vehiclesSubscription.cancel();
    _selfVehicleSubscription.cancel();
    _requestSubscription.cancel();
    _chatResponseController.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usbManager = Provider.of<UsbConnectionManager>(context);
    print("Connected Vehicle: ${usbManager.connectedVehicle?['status']}");
    return Scaffold(
      body: Column(
        children: [
          // Connection status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Connection Status:'),
                      Chip(
                        label: Text(
                          usbManager.status,
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor:
                            usbManager.status == "Connected"
                                ? Colors.green
                                : Colors.red,
                      ),
                    ],
                  ),
                  if (usbManager.connectedDevice != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Connected to: ${usbManager.connectedDevice?.productName}',
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: usbManager.disconnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Changed from 'primary'
                        foregroundColor: Colors.white, // Optional: text color
                      ),
                      child: Text('Disconnect'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child:
                usbManager.connectedDevice == null
                    ? _buildDeviceList(usbManager)
                    : usbManager.connectedVehicle?['status'] == "Connected"
                    ? ConnectedView()
                    : Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: RadarView(
                              selfLatitude:
                                  usbManager.selfVehicleInfo['latitude'],
                              selfLongitude:
                                  usbManager.selfVehicleInfo['longitude'],
                              vehicles: usbManager.vehicleInfo,
                            ),
                          ),
                          Expanded(child: _buildVehicleList(usbManager)),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(UsbConnectionManager usbManager) {
    if (usbManager.availableDevices.isEmpty) {
      return Center(child: Text('No USB devices found'));
    }
    print(usbManager.availableDevices);

    return ListView.builder(
      itemCount: usbManager.availableDevices.length,
      itemBuilder: (context, index) {
        final device = usbManager.availableDevices[index];
        return ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName ?? 'Unknown Device'),
          subtitle: Text(device.manufacturerName ?? 'Unknown Manufacturer'),
          trailing: ElevatedButton(
            child: Text('Connect'),
            onPressed: () => usbManager.connectToDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildVehicleList(UsbConnectionManager usbManager) {
    if (usbManager.vehicleInfo.isEmpty) {
      return Center(child: Text('No nearby vehicles detected'));
    }

    return ListView.builder(
      itemCount: usbManager.vehicleInfo.length,
      itemBuilder: (context, index) {
        final vehicle = usbManager.vehicleInfo[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle ${vehicle['id']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildInfoRow('Status:', vehicle['status']),
                _buildInfoRow('Speed:', '${vehicle['speed']} km/h'),
                _buildInfoRow(
                  'Position:',
                  'Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}',
                ),
                _buildInfoRow('Last Update:', vehicle['lastReceivedTime']),
                if (vehicle['mac'] != null)
                  _buildInfoRow('MAC:', vehicle['mac']),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Implement connection initiation
                    usbManager.sendChatRequest(vehicle['mac'], vehicle['id']);
                  },
                  child: Text('Connect to Vehicle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
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

class ConnectedView extends StatefulWidget {
  const ConnectedView({super.key});

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
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );
    _chatMessageSubscription = usbManager.chatMessageStream.listen((message) {
      if (message['mac'] == usbManager.connectedVehicle?['mac']) {
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
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );
    usbManager.sendChatMessage(
      _messageController.text,
      usbManager.connectedVehicle?['mac'],
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
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );
    usbManager.sendChatResponse(
      "Disconnect",
      usbManager.connectedVehicle?['mac'],
      usbManager.selfVehicle['vehicle'],
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final usbManager = Provider.of<UsbConnectionManager>(context);
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
                  usbManager.connectedVehicle?['vehicle'],
                ),
                _buildConnectionInfoRow(
                  'MAC Address:',
                  usbManager.connectedVehicle?['mac'],
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
    final usbManager = Provider.of<UsbConnectionManager>(context);
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
                      : usbManager.connectedVehicle?['vehicle'] ?? 'Unknown',
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
