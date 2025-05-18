import 'package:flutter/material.dart';
import 'package:vivan_app/screens/HomeScreen.dart';
import 'package:vivan_app/screens/VoiceChatScreen.dart';
import 'package:vivan_app/screens/SelfVehicleScreen.dart';
import 'package:vivan_app/screens/DevelopersScreen.dart';
import 'package:vivan_app/screens/SettingsScreen.dart';

class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    Voicechatscreen(),
    Selfvehiclescreen(),
    Developersscreen(),
    Settingsscreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VIVAN App')),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_phone),
            label: 'Voice Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Self Vehicle',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Developers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
