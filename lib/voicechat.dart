import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:vivan_app/main.dart';

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

Future<void> _toggleRecording() async {
  // if (_isRecording) {
  //   // await _stopRecording();
  // } else {
  //   // await _startRecording();
  // }
}

Future<void> _processAndSendRecording() async {
  // if (_hasRecording) {
  //   // Process and send the recording
  //   await _sendRecording();
  // }
}

class VoiceChat extends StatelessWidget {
  final bool _isRecording = false;

  // final AudioPlayer _audioPlayer = AudioPlayer();
  // List<Map<String, dynamic>> _receivedPackets = [];
  final bool _isReceiving = false;
  // final AudioRecorder _audioRecorder = AudioRecorder();
  // final ADPCMEncoder _encoder = ADPCMEncoder();
  final bool _hasRecording = false;
  final Duration _recordingDuration = Duration.zero;
  final List<String> _packetLogs = [];

  final UsbConnectionManager? usbOldConnection;
  VoiceChat({this.usbOldConnection});

  // final UsbSerialManagerVoice usbManager = UsbSerialManagerVoice(

  final usbManager = UsbSerialManagerVoice(
    onDataReceived: (data) {
      print('Received Secondary: $data');
    },
  );

  @override
  Widget build(BuildContext context) {
    print("Voice Build Widget Started!!!!!!!!!!!!");
    print(usbOldConnection?.connectedDevice);

    // Check if the USB connection is established
    if (usbOldConnection?.connectedDevice == null) {
      return Center(child: Text('USB device not connected'));
    }

    usbManager.connect(usbOldConnection!.connectedDevice!);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Record button
          GestureDetector(
            onLongPress: _toggleRecording,
            onLongPressUp: _toggleRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.blue,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _isRecording
                ? 'Recording: ${_recordingDuration.inSeconds}s'
                : _hasRecording
                ? 'Recording ready to send'
                : 'Press and hold to record',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          if (_hasRecording)
            ElevatedButton(
              onPressed: _processAndSendRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text('Process and Send'),
            ),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _packetLogs.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_packetLogs[index]), dense: true);
              },
            ),
          ),
          if (_isReceiving) CircularProgressIndicator(),
          // if (_receivedPackets.isNotEmpty && !_isReceiving)
          //   ElevatedButton(
          //     onPressed: _decodeAndPlayAudio,
          //     child: Text('Play Received Audio'),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.orange,
          //       padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          //     ),
          //   ),
        ],
      ),
    );
  }
}
