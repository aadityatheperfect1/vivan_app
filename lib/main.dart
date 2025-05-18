// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vivan_app/UsbConnectionManager.dart';
import 'package:vivan_app/MainNavigationPage.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<UsbConnectionManager>(
          create: (_) => UsbConnectionManager(),
          dispose: (_, manager) => manager.dispose(),
        ),
      ],
      child: VivanApp(),
    ),
  );
}

class VivanApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIVAN App',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.indigo,
          secondary: Colors.amber,
          surface: Colors.grey[50]!,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(8),
        ),
      ),
      home: MainNavigationPage(),
    );
  }
}
