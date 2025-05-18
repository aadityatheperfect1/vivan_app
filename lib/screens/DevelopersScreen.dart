import 'package:flutter/material.dart';

class Developersscreen extends StatefulWidget {
  const Developersscreen({super.key});

  @override
  State<Developersscreen> createState() => _DevelopersscreenState();
}

class _DevelopersscreenState extends State<Developersscreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('VIVAN Serial Monitor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Developers', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
