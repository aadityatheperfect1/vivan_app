import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:vivan_app/main1.dart';

class UsbSerialManagerVoice {
  UsbPort? _port;
  UsbDevice? _device;
  bool _isConnected = false;

  // Callback for received data
  final Function(String)? onDataReceived;

  UsbSerialManagerVoice({this.onDataReceived});

  // Get list of available devices
  Future<List<UsbDevice>> getAvailableDevices() async {
    return await UsbSerial.listDevices();
  }

  // Connect to a specific device
  Future<bool> connect(UsbDevice device) async {
    await disconnect(); // Disconnect any existing connection

    try {
      _port = await device.create();
      if (!(await _port!.open())) {
        return false;
      }

      await _port!.setPortParameters(
        115200, // Baud rate
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // // Listen for incoming data
      // _port!.inputStream!.listen((Uint8List data) {
      //   if (onDataReceived != null) {
      //     onDataReceived!(String.fromCharCodes(data));
      //   }
      // });

      final transaction = Transaction.stringTerminated(
        _port!.inputStream!.asBroadcastStream(),
        Uint8List.fromList([13, 10]),
      );

      transaction.stream.listen(
        (String line) {
          if (onDataReceived != null) {
            onDataReceived!(line);
          }
        },
        onDone: () {
          disconnect();
        },
      );

      _device = device;
      _isConnected = true;
      return true;
    } catch (e) {
      disconnect();
      return false;
    }
  }

  // Send data to the connected device
  Future<void> send(String data) async {
    if (!_isConnected || _port == null) return;
    await _port!.write(Uint8List.fromList(data.codeUnits));
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    await _port?.close();
    _port = null;
    _device = null;
    _isConnected = false;
  }

  // Check if connected
  bool get isConnected => _isConnected;

  // Get connected device info
  UsbDevice? get connectedDevice => _device;

  // Cleanup
  void dispose() {
    disconnect();
  }
}

// Future<void> _toggleRecording() async {
//   // if (_isRecording) {
//   //   // await _stopRecording();
//   // } else {
//   //   // await _startRecording();
//   // }
// }

// Future<void> _processAndSendRecording() async {
//   // if (_hasRecording) {
//   //   // Process and send the recording
//   //   await _sendRecording();
//   // }
// }

class VoiceState extends StatefulWidget {
  final UsbConnectionManager? usbOldConnection;

  VoiceState({required this.usbOldConnection});

  @override
  State<VoiceState> createState() => _VoiceStateState();
}

class _VoiceStateState extends State<VoiceState> {
  UsbDevice? device;

  UsbSerialManagerVoice? usbSerialManagerVoice = UsbSerialManagerVoice(
    onDataReceived: (String data) {
      // Handle incoming data here
      print('Received: $data');
    },
  );

  @override
  void initState() {
    super.initState();
    device = widget.usbOldConnection!.connectedDevice!;
  }

  @override
  Widget build(BuildContext context) {
    usbSerialManagerVoice!.connect(device!);

    if (usbSerialManagerVoice!._isConnected) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Connected to ${usbSerialManagerVoice!.connectedDevice?.productName}',
          ),
          ElevatedButton(
            onPressed: () {
              // Send data to the connected device
              usbSerialManagerVoice!.send('Hello from Flutter!');
            },
            child: Text('Send Data'),
          ),
        ],
      );
    } else {
      return Text('No device connected');
    }
  }

  @override
  void dispose() {
    usbSerialManagerVoice?.dispose();
    super.dispose();
  }
}
