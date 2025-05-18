import 'package:flutter/material.dart';

class Voicechatscreen extends StatefulWidget {
  const Voicechatscreen({super.key});

  @override
  State<Voicechatscreen> createState() => _VoicechatscreenState();
}

class _VoicechatscreenState extends State<Voicechatscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('VIVAN Serial Monitor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Voice Chat', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
