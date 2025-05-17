import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:vivan_app/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

Future<void> requestMicrophonePermission() async {
  final micStatus = await Permission.microphone.request();

  if (micStatus.isGranted) {
    print("Microphone permission granted");
  } else {
    print("Microphone Permissions not granted");
    // openAppSettings(); // Optional: direct user to app settings
  }

  // Request storage permission depending on Android version
  if (await Permission.manageExternalStorage.isGranted == false &&
      await Permission.storage.isGranted == false) {
    // Request manage storage permission (for Android 11+)
    await Permission.manageExternalStorage.request();
    await Permission.storage.request();
  }

  // Optional: check if still denied
  if (await Permission.storage.isDenied) {
    print("Storage permission denied");
  }
}

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

void onDataReceived(String data) {
  // Handle incoming data here
  print('Received XXX: $data');
}

Future<String> getRecordingPath() async {
  final dir = await getExternalStorageDirectory();
  if (dir == null) {
    throw Exception('Unable to get external storage directory');
  }
  final recordingsDir = Directory('${dir.path}/Recordings');
  if (!await recordingsDir.exists()) {
    await recordingsDir.create();
  }
  return '${recordingsDir.path}/tempRecording.m4a';
  // return 'tempFile.m4a'; // Use a temporary file for testing
}

class VoiceState extends StatefulWidget {
  final UsbConnectionManager? usbOldConnection;

  final Map<String, dynamic>? connectedVehicle;

  VoiceState({required this.usbOldConnection, required this.connectedVehicle});

  @override
  State<VoiceState> createState() => _VoiceStateState();
}

class _VoiceStateState extends State<VoiceState> {
  UsbDevice? device;
  late UsbConnectionManager? usbConnection;
  UsbPort? port;
  bool _isRecording = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  final List<String> _packetLogs = [];
  final bool _isReceiving = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;

  Future<void> _processAndSendRecording() async {
    if (_recordingPath == null || _recordingPath!.isEmpty) {
      print("No recording available to send");
      return;
    }

    //get aac frames
    final file = File(_recordingPath!);
    final m4aBytes = await file.readAsBytes();
    final aacFrames = extractAACFrames(m4aBytes);
    print("AAC Frames: $aacFrames");

    // Packetize Recording

    setState(() {
      _hasRecording = false;
    });

    try {
      final payload = {
        "type": "voiceRequest",
        "vehicle": widget.connectedVehicle?['vehicle'],
        "mac": widget.connectedVehicle?['mac'],
        "sequence": 0,
      };
      final msg = '${jsonEncode(payload)}\n';
      port?.write(Uint8List.fromList(msg.codeUnits));
    } catch (e) {
      print(e);
    }

    // if (_hasRecording) {
    //   // Process and send the recording
    //   await _sendRecording();
    // }
  }

  Future<void> _startRecording() async {
    final path = await getRecordingPath();
    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // Most efficient for voice
          bitRate: 16000, // 16 kbps (minimum for intelligible voice)
          sampleRate: 8000, // 8kHz (narrowband, standard for VoIP)
          numChannels: 1, // Mono
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _recordingPath = path;
        _packetLogs.clear();
      });

      // Update recording duration
      Timer.periodic(Duration(seconds: 1), (timer) {
        if (!_isRecording) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration += Duration(seconds: 1);
        });
      });
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _hasRecording = true;
      _recordingPath = path;
      _recordingDuration = Duration.zero;
    });
    print('Recording saved to: $path');
  }

  Future<void> _toggleRecording() async {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      // Start recording
      await _startRecording();
    } else {
      // Stop recording
      await _stopRecording();
    }
  }

  List<Uint8List> extractAACFrames(Uint8List m4aBytes) {
    List<Uint8List> frames = [];
    int pos = 0;

    while (pos + 7 < m4aBytes.length) {
      // Check for ADTS sync word (0xFFF)
      if (m4aBytes[pos] == 0xFF && (m4aBytes[pos + 1] & 0xF0) == 0xF0) {
        // Calculate frame length from ADTS header
        int frameLength =
            ((m4aBytes[pos + 3] & 0x03) << 11) |
            (m4aBytes[pos + 4] << 3) |
            ((m4aBytes[pos + 5] & 0xE0) >> 5);

        if (pos + frameLength <= m4aBytes.length) {
          frames.add(m4aBytes.sublist(pos, pos + frameLength));
          pos += frameLength;
        } else {
          break; // Incomplete frame
        }
      } else {
        pos++; // Skip corrupted data
      }
    }
    return frames;
  }

  Future<void> sendAACFrames(List<Uint8List> aacFrames, UsbPort usbPort) async {
    int frameId = 0;

    for (var frame in aacFrames) {
      // Split into 246-byte chunks (250B ESP-NOW limit - 4B header)
      final chunkSize = 246;
      final totalChunks = (frame.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end =
            (i + 1) * chunkSize < frame.length
                ? (i + 1) * chunkSize
                : frame.length;
        final chunk = frame.sublist(start, end);

        // Create a Uint8List for the packet (4B header + AAC chunk)
        final packet = Uint8List(4 + chunk.length);

        // Use ByteData to write structured headers
        final byteData = ByteData.view(packet.buffer);
        byteData.setUint16(0, frameId, Endian.big); // Frame ID (2 bytes)
        byteData.setUint8(2, i); // Chunk index (1 byte)
        byteData.setUint8(3, totalChunks); // Total chunks (1 byte)

        // Copy AAC chunk data
        packet.setRange(4, 4 + chunk.length, chunk);

        // Send to ESP32 over USB
        await usbPort.write(packet);
      }

      frameId++;
    }
  }

  Future<void> _playMessage() async {
    final file = File(_recordingPath!);
    if (!file.existsSync()) {
      print("File does not exist at: $_recordingPath");
      return;
    }

    if (_recordingPath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordingPath!));
    }
  }

  UsbSerialManagerVoice? usbSerialManagerVoice = UsbSerialManagerVoice(
    onDataReceived: (String data) {
      // Handle incoming data here
      print('Received: $data');
    },
  );

  @override
  void initState() {
    super.initState();
    device = widget.usbOldConnection?.connectedDevice;
    usbConnection = widget.usbOldConnection;

    if (device != null) {
      usbSerialManagerVoice?.connect(device!);
    } else {
      print("No USB device connected.");
    }

    requestMicrophonePermission().then((_) {
      print("Microphone permission requested.");
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Voice Build Widget Started!!!!!!!!!!!!");
    print("Hello: ${usbConnection!.connectedDevice?.productName} ");
    if (usbConnection?.connectedDevice == null) {
      return Center(child: Text('USB device not connected'));
    }

    if (widget.connectedVehicle?['vehicle'] == null) {
      return Center(child: Text('No Vehicle connected'));
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Color(0xFFF9FAFB),
              child: SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      'Send Voice Message',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 40),
                    if (!_hasRecording)
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
                    if (_hasRecording)
                      GestureDetector(
                        onTap: _processAndSendRecording,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                          child: Icon(
                            Icons.send,
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
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Color(0xFFE5E7EB),
              child: SizedBox.expand(
                child: SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Received Message',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (4 < 2) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        const Text(
                          'Receiving message...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ] else if (_recordingPath != null &&
                          _recordingPath!.isNotEmpty) ...[
                        TextButton.icon(
                          onPressed: _playMessage,
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'Play Message',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              211,
                              243,
                              27,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'No message available',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Expanded(
                        child: ListView.builder(
                          itemCount: _packetLogs.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(_packetLogs[index]),
                              dense: true,
                            );
                          },
                        ),
                      ),

                      if (_isReceiving)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // if (usbSerialManagerVoice!._isConnected) {
    // } else {
    //   return Text('No device connected');
    // }
  }

  @override
  void dispose() {
    usbSerialManagerVoice?.dispose();
    super.dispose();
  }
}
