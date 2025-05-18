import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';
// import 'package:vivan_app/voicechat.dart';

class UsbConnectionManager {
  // Make constructor private
  UsbConnectionManager._privateConstructor();

  // Static instance
  static final UsbConnectionManager _instance =
      UsbConnectionManager._privateConstructor();

  // Factory constructor to return the same instance
  factory UsbConnectionManager() => _instance;

  UsbPort? _port;
  UsbDevice? _device;
  String _status = "Disconnected";
  List<UsbDevice> _availableDevices = [];
  List<Map<String, dynamic>> vehicleInformation = [];

  final Map<String, dynamic> _connectedVehicle = {
    "name": "Unknown",
    "mac": "00:00:00:00:00:00",
    "status": "Disconnected",
  };

  Map<String, dynamic>? get connectedVehicle => _connectedVehicle;

  Map<String, dynamic> selfVehicle = {
    'latitude': -1.0,
    'longitude': -1.0,
    'speed': -1.0,
    'vehicle': 'Unknown',
    'time': 'Time Unavailable',
    'status': 'Disconnected',
  };

  void setConnectedVehicle(Map<String, dynamic> vehicle) {
    _connectedVehicle['name'] = vehicle['name'];
    _connectedVehicle['mac'] = vehicle['mac'];
    _connectedVehicle['status'] = vehicle['status'];
    // notifyListeners();
  }

  void setConnectedDevice(UsbDevice device) {
    _device = device;
    // notifyListeners();
  }

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

  Future<void> sendChatRequest(String mac, String vehicle) async {
    if (_port == null) return;

    try {
      final payload = {
        "type": "ChatRequest",
        "mac": mac,
        "vehicle": vehicle,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };

      final message = '${jsonEncode(payload)}\n';
      await _port!.write(Uint8List.fromList(message.codeUnits));
    } catch (e) {
      debugPrint("Error sending chat request: $e");
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
    print("Available devices: $_availableDevices");
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

      // _status = "Connected to ${device.productName ?? 'device'}";
      _status = "Connected";
      selfVehicle['status'] = 'Connected';
      _statusController.add(_status);
      _selfVehicleController.add(selfVehicle);
      // notifyListeners();
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
    // notifyListeners();
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
