import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:vivan_app/UsbConnectionManager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

class Voicechatscreen extends StatefulWidget {
  const Voicechatscreen({super.key});

  @override
  State<Voicechatscreen> createState() => _VoicechatscreenState();
}

class _VoicechatscreenState extends State<Voicechatscreen> {
  bool isRecording = false;
  bool isPlaying = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  final AudioRecorder audioRecorder = AudioRecorder();
  final bool _isReceiving = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  String _spokenText = '';
  bool _isListening = false;
  Timer? _recordingTimer;

  String _receivedMessage = '';

  bool isDeviceConnected = false;
  bool isVehicleConnected = false;

  late StreamSubscription<String> _statusSubscription;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _vehicleSubscription;
  StreamSubscription? _messageSubscription;

  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage("en-IN");
    await flutterTts.setSpeechRate(0.5); // Speed of speech (0 to 1)
    await flutterTts.setVolume(1.0); // Volume (0 to 1)
    await flutterTts.setPitch(1.0); // Pitch (0.5 to 2.0)
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition not available");
    }
  }

  void initState() {
    super.initState();
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    _statusSubscription = usbManager.statusStream.listen((status) {
      setState(() {
        isDeviceConnected = status == 'Connected';
      });
    });

    _initializeTts();
    _initSpeech();
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

    _vehicleSubscription = usbManager.vehiclesStream.listen((response) {
      if (mounted) setState(() {});
    });

    _messageSubscription = usbManager.voiceMessageStream.listen((message) {
      if (mounted) {
        setState(() {
          _receivedMessage = message;
        });
      }
    });
  }

  Future<void> _processAndSendRecording() async {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    print("Sending message: $_spokenText");

    if (_spokenText.isNotEmpty) {
      await usbManager.sendVoiceMessage(
        _spokenText,
        '${usbManager.connectedVehicle?['mac'] ?? ''}',
      );
    } else {
      print("No recording to send");
    }
    setState(() {
      _hasRecording = false;
    });
  }

  Future<void> _startListening() async {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _spokenText = result.recognizedWords;
        });
      },
    );
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    _recordingTimer?.cancel();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _hasRecording = true;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _toggleRecording() async {
    if (!_isListening) {
      // Start recording
      print("Recording started");
      await _startListening();
    } else {
      // Stop recording
      await _stopListening();
    }
  }

  Future<void> _playMessage() async {
    await flutterTts.speak(_receivedMessage);
  }

  void dispose() {
    _statusSubscription.cancel();
    flutterTts.stop();
    _recordingTimer?.cancel();
    _connectionSubscription?.cancel();
    _vehicleSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
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
          return const Center(child: Text('No vehicle connected'));
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
                                color: _isListening ? Colors.red : Colors.blue,
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
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
                          _isListening
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

                          if (_receivedMessage.isNotEmpty) ...[
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
        // if (usbSerialManagerVoice!._isConnected) {
        // } else {
        //   return Text('No device connected');
        // }
      },
    );
  }
}
