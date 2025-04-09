import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';

class UsbSerialManager {
  UsbPort? _port;
  UsbDevice? _device;
  bool _isConnected = false;

  // Callback for received data
  final Function(String)? onDataReceived;

  UsbSerialManager({this.onDataReceived});

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

      // Listen for incoming data
      _port!.inputStream!.listen((Uint8List data) {
        if (onDataReceived != null) {
          onDataReceived!(String.fromCharCodes(data));
        }
      });

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

class VoiceChat extends StatelessWidget {
  final usbManager = UsbSerialManager(
    onDataReceived: (data) {
      print('Received: $data');
    },
  );

  @override
  Widget build(BuildContext context) {
    usbManager.getAvailableDevices().then((devices) {
      if (devices.isNotEmpty) {
        usbManager.connect(devices[0]).then((success) {
          if (success) {
            print('Connected to ${usbManager.connectedDevice}');
          } else {
            print('Failed to connect');
          }
        });
      } else {
        print('No devices found');
      }
    });

    return Center(
      child: Text('Voice Chat Page Separately', style: TextStyle(fontSize: 24)),
    );
  }
}
