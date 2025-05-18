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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'OK':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

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
        print(response);
        usbManager.connectedVehicle?['mac'] = response['mac'];
        usbManager.connectedVehicle?['name'] = response['vehicle'];
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
                  usbManager.connectedVehicle?['mac'] = request['mac'];
                  usbManager.connectedVehicle?['vehicle'] = request['vehicle'];
                  usbManager.connectedVehicle?['status'] = "Connected";
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
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey[50],
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.usb, color: Colors.blueGrey, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'USB Connection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              usbManager.status == "Connected"
                                  ? Colors.green[100]
                                  : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                usbManager.status == "Connected"
                                    ? Colors.green
                                    : Colors.red,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          usbManager.status,
                          style: TextStyle(
                            color:
                                usbManager.status == "Connected"
                                    ? Colors.green[800]
                                    : Colors.red[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (usbManager.connectedDevice != null) ...[
                    SizedBox(height: 8),
                    Text(
                      usbManager.connectedDevice?.productName ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: usbManager.disconnect,
                        icon: Icon(Icons.power_settings_new, size: 16),
                        label: Text(
                          'Disconnect',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child:
                  usbManager.connectedDevice == null
                      // 🔌 Show device list when no USB device connected
                      ? _buildDeviceList(usbManager)
                      // ✅ Show connected vehicle UI if fully connected
                      : usbManager.connectedVehicle?['status'] == "Connected"
                      ? ConnectedView()
                      // 📡 Show radar + vehicle list if only USB connected
                      : Column(
                        children: [
                          // Radar Section
                          Container(
                            padding: const EdgeInsets.all(0),
                            child: SizedBox(
                              child: RadarView(
                                selfLatitude:
                                    usbManager.selfVehicleInfo['latitude'],
                                selfLongitude:
                                    usbManager.selfVehicleInfo['longitude'],
                                vehicles: usbManager.vehicleInfo,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Vehicle List Section
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(0),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                              ),
                              child: _buildVehicleList(usbManager),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle ID and Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vehicle ${vehicle['id']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _getStatusColor(vehicle['status'] ?? ''),
                        ),
                        SizedBox(width: 6),
                        Text(
                          vehicle['status'] ?? 'Unknown',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Compact details
                _infoRow(Icons.speed, '${vehicle['speed']} km/h'),
                _infoRow(
                  Icons.location_on,
                  'Lat: ${vehicle['latitude']}, Lon: ${vehicle['longitude']}',
                  maxLines: 1,
                ),
                _infoRow(Icons.access_time, vehicle['lastReceivedTime'] ?? '—'),
                if (vehicle['mac'] != null)
                  _infoRow(Icons.wifi, vehicle['mac']),

                SizedBox(height: 10),

                // Connect Button
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: BorderSide(color: Colors.indigo),
                    ),
                    icon: Icon(Icons.link),
                    label: Text('Connect'),
                    onPressed: () {
                      usbManager.sendChatRequest(vehicle['mac'], vehicle['id']);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text, {int maxLines = 2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
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

class _RadarCrossPainter extends CustomPainter {
  final Color color;

  _RadarCrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Colors.grey.shade100, Colors.grey.shade300],
            center: Alignment.center,
            radius: 1.0,
          ),
          border: Border.all(color: Colors.indigo.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.1),
              blurRadius: 6,
              spreadRadius: 1,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Two radar rings with good spacing
            ...[60.0, 105.0].map((radius) {
              return Positioned(
                left: 150 - radius,
                top: 150 - radius,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.indigo.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            }),

            // Radar cross lines
            Positioned.fill(
              child: CustomPaint(
                painter: _RadarCrossPainter(
                  color: Colors.indigo.withOpacity(0.3),
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
                77.0339556,
                vehicleLat,
                vehicleLon,
              );

              final angle = calculateAngle(
                8.6279986,
                77.0339556,
                vehicleLat,
                vehicleLon,
              );

              final scaledDistance = min(distance, 150) / 150 * 120;
              final radian = angle * pi / 180;
              final x = 150 + scaledDistance * cos(radian);
              final y = 150 + scaledDistance * sin(radian);

              return Positioned(
                left: x - 10,
                top: y - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(vehicle['status']?.toString() ?? ''),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      vehicle['id']?.toString().substring(0, 1) ?? '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),

            // Center vehicle (self)
            Positioned(
              left: 143,
              top: 143,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
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
      case 'OK':
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
        // Connection Status Card
        Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // Connection Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CONNECTED',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.signal_wifi_4_bar,
                      color: Colors.green[700],
                      size: 24,
                    ),
                  ],
                ),
                SizedBox(height: 5),

                // Connection Info - Compact Two Column Layout
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: [
                    _buildConnectionInfoRow(
                      'Vehicle: ',
                      usbManager.connectedVehicle?['vehicle'],
                    ),
                    _buildConnectionInfoRow(
                      'MAC:',
                      usbManager.connectedVehicle?['mac'],
                    ),
                  ],
                ),
                SizedBox(height: 6),

                // Disconnect Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _disconnect,
                    icon: Icon(Icons.link_off, size: 18),
                    label: Text('DISCONNECT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chat Area
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: false,
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.only(top: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),

                // Message Input
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 4),
                  child: _buildMessageInput(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper method for connection info rows
  TableRow _buildConnectionInfoRow(String label, String? value) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value ?? '--',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // Widget _buildConnectionInfoRow(String label, String value) {
  //   return Padding(
  //     padding: EdgeInsets.symmetric(vertical: 4),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           label,
  //           style: TextStyle(
  //             fontWeight: FontWeight.bold,
  //             color: Colors.grey[700],
  //           ),
  //         ),
  //         SizedBox(width: 8),
  //         Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
  //       ],
  //     ),
  //   );
  // }

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
