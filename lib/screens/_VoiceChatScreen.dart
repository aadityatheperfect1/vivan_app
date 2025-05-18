import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vivan_app/UsbConnectionManager.dart'; // your own manager

class VehicleChatScreen extends StatefulWidget {
  const VehicleChatScreen({Key? key}) : super(key: key);

  @override
  State<VehicleChatScreen> createState() => _VehicleChatScreenState();
}

class _VehicleChatScreenState extends State<VehicleChatScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  String _spokenText = '';
  List<Map<String, String>> _chatLog = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _startListeningToIncoming();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition not available");
    }
  }

  void _startListeningToIncoming() {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );
    usbManager.chatMessageStream.listen((data) {
      final msg = data['message'];
      final mac = data['mac'];

      setState(() {
        _chatLog.add({'from': mac ?? 'Unknown', 'msg': msg ?? ''});
      });

      if (msg != null) _speak(msg);
    });
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage("en-IN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
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
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _sendMessage() {
    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );
    final payload = {
      "type": "ChatMessage",
      "vehicle": usbManager.connectedVehicle?['name'],
      "mac": usbManager.connectedVehicle?['mac'],
      "message": _spokenText,
    };
    final msg = '${jsonEncode(payload)}\n';
    usbManager.port?.write(Uint8List.fromList(msg.codeUnits));

    setState(() {
      _chatLog.add({'from': 'Me', 'msg': _spokenText});
      _spokenText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Voice Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _chatLog.length,
                itemBuilder: (context, index) {
                  final entry = _chatLog[index];
                  return ListTile(
                    title: Text(entry['msg'] ?? ''),
                    subtitle: Text('From: ${entry['from'] ?? ''}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _spokenText.isEmpty
                  ? 'Press mic to speak...'
                  : 'You said:\n$_spokenText',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  child: Icon(_isListening ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _spokenText.isEmpty ? null : _sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
