import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:vivan_app/UsbConnectionManager.dart';

List<Uint8List> simulatedReceivedPackets = [];
Uint8List? _reconstructedAACData;

Future<void> requestMicrophonePermission() async {
  final micStatus = await Permission.microphone.request();
  if (micStatus.isGranted) {
    print("Microphone permission granted");
  } else {
    print("Microphone Permissions not granted");
  }

  if (await Permission.manageExternalStorage.isGranted == false &&
      await Permission.storage.isGranted == false) {
    await Permission.manageExternalStorage.request();
    await Permission.storage.request();
  }

  if (await Permission.storage.isDenied) {
    print("Storage permission denied");
  }
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
}

class Voicechatscreen extends StatefulWidget {
  const Voicechatscreen({super.key});

  @override
  State<Voicechatscreen> createState() => _VoicechatscreenState();
}

class _VoicechatscreenState extends State<Voicechatscreen> {
  bool isRecording = false;
  String _recordingPath = '';
  final AudioPlayer audioPlayer = AudioPlayer();
  final AudioRecorder audioRecorder = AudioRecorder();
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  bool _isReceiving = false;

  bool _isReadytoPlay = false;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _vehicleSubscription;

  @override
  void initState() {
    super.initState();
    requestMicrophonePermission();
    _setupConnectionListeners();
  }

  void _setupConnectionListeners() {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    _connectionSubscription = usbManager.statusStream.listen((status) {
      if (mounted) setState(() {});
    });

    _vehicleSubscription = usbManager.chatResponseStream.listen((response) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _vehicleSubscription?.cancel();
    _recordingTimer?.cancel();
    audioPlayer.dispose();
    audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _processAndSendRecording() async {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    if (_recordingPath.isEmpty) {
      print("No recording available to send");
      return;
    }

    try {
      final file = File(_recordingPath);
      final m4aBytes = await file.readAsBytes();
      final aacFrames = extractAACFrames(m4aBytes);
      print("AAC Frames extracted: ${aacFrames.length}");

      // final payload = {
      //   "type": "voiceRequest",
      //   "vehicle": usbManager.connectedVehicle?['name'],
      //   "mac": usbManager.connectedVehicle?['mac'],
      //   "sequence": 0,
      // };

      // final msg = '${jsonEncode(payload)}\n';
      // print("Sending: $msg");
      // usbManager.usbPort?.write(Uint8List.fromList(msg.codeUnits));

      // Send the AAC frames
      await sendAACFrames(aacFrames);
      // print("AAC frames sent successfully");

      // print("Data to send: ${m4aBytes.length} bytes");
      // print(m4aBytes);

      setState(() {
        _hasRecording = false;
        _recordingPath = '';
      });
    } catch (e) {
      print("Error sending recording: $e");
    }
  }

  Future<void> _startRecording() async {
    final path = await getRecordingPath();
    try {
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 16000,
          sampleRate: 8000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        isRecording = true;
        _hasRecording = false;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!isRecording) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      print('Error starting recording: $e');
      setState(() => isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await audioRecorder.stop();
      setState(() {
        isRecording = false;
        _hasRecording = true;
        _recordingPath = path!;
      });
      print('Recording saved to: $path');
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() => isRecording = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  List<Uint8List> extractAACFrames(Uint8List m4aBytes) {
    List<Uint8List> frames = [];
    int pos = 0;

    while (pos + 7 < m4aBytes.length) {
      if (m4aBytes[pos] == 0xFF && (m4aBytes[pos + 1] & 0xF0) == 0xF0) {
        int frameLength =
            ((m4aBytes[pos + 3] & 0x03) << 11) |
            (m4aBytes[pos + 4] << 3) |
            ((m4aBytes[pos + 5] & 0xE0) >> 5);

        if (pos + frameLength <= m4aBytes.length) {
          frames.add(m4aBytes.sublist(pos, pos + frameLength));
          pos += frameLength;
        } else {
          break;
        }
      } else {
        pos++;
      }
    }
    return frames;
  }

  Future<void> sendAACFrames(List<Uint8List> aacFrames) async {
    simulatedReceivedPackets.clear();
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    final usbPort = usbManager.port;
    int frameId = 0;

    for (var frame in aacFrames) {
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
        // await usbPort?.write(packet);
        simulatedReceivedPackets.add(packet);
        await Future.delayed(Duration(milliseconds: 100));

        // Simulate sending
      }

      frameId++;
    }

    print("All frames sent successfully");
    await Future.delayed(Duration(milliseconds: 300));

    print("Simulated received packets: $simulatedReceivedPackets");
    await reassembleSimulatedAudio();
  }

  Future<void> reassembleSimulatedAudio() async {
    setState(() {
      _isReceiving = true;
      _isReadytoPlay = false;
    });
    final Map<int, Map<int, Uint8List>> frames = {};

    // Group packets by frameId and chunkIndex
    for (var packet in simulatedReceivedPackets) {
      final byteData = ByteData.view(packet.buffer);
      final frameId = byteData.getUint16(0, Endian.big);
      final chunkIndex = byteData.getUint8(2);
      final aacChunk = packet.sublist(4);

      if (!frames.containsKey(frameId)) {
        frames[frameId] = {};
      }
      frames[frameId]![chunkIndex] = aacChunk;
    }

    // Reconstruct AAC frames
    final reconstructedFrames =
        frames.values.map((chunks) {
          final frameLength = chunks.values.fold(
            0,
            (sum, chunk) => sum + chunk.length,
          );
          final frame = Uint8List(frameLength);
          int pos = 0;

          for (int i = 0; i < chunks.length; i++) {
            final chunk = chunks[i]!;
            frame.setRange(pos, pos + chunk.length, chunk);
            pos += chunk.length;
          }
          return frame;
        }).toList();

    // Combine all frames into one Uint8List

    if (frames.isEmpty || reconstructedFrames.isEmpty) {
      print("Error: No frames to reconstruct");
      return;
    }
    _reconstructedAACData = Uint8List.fromList(
      reconstructedFrames.expand((frame) => frame).toList(),
    );

    setState(() {
      _isReceiving = false;
      _recordingPath = '';
      _isReadytoPlay = true;
    });

    print("Audio reassembled. Ready to play.");
    print(
      "Reconstructed AAC data size: ${_reconstructedAACData!.length} bytes",
    );
    print("Reconstructed AAC data: ${_reconstructedAACData}");
  }

  Future<void> _playMessage() async {
    if (_reconstructedAACData == null) {
      print("No audio data to play.");
      return;
    }

    final tempFile = File(
      '${(await getTemporaryDirectory()).path}/reconstructed.aac',
    );
    await tempFile.writeAsBytes(_reconstructedAACData!);

    print("File size: ${tempFile.lengthSync()} bytes");
    final header = await tempFile.readAsBytes().then(
      (bytes) => bytes.sublist(0, 3),
    );
    print("File starts with: ${header.map((b) => b.toRadixString(16))}");

    await audioPlayer.play(DeviceFileSource(tempFile.path));
    print("Playing audio...");
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsbConnectionManager>(
      builder: (context, usbManager, child) {
        final isDeviceConnected = usbManager.connectedDevice != null;
        final isVehicleConnected =
            usbManager.connectedVehicle?['status'] == 'Connected';

        if (!isDeviceConnected) {
          return const Center(child: Text('USB device not connected'));
        }

        if (!isVehicleConnected) {
          return const Center(child: Text('No Vehicle connected'));
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
                                color: isRecording ? Colors.red : Colors.blue,
                              ),
                              child: Icon(
                                isRecording ? Icons.stop : Icons.mic,
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
                          isRecording
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

                          if (_isReceiving) ...[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            const Text(
                              'Receiving message...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ] else if (_isReadytoPlay) ...[
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
      },
    );
  }
}
