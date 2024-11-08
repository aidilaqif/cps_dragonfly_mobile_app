import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const CPSApp());
}

class CPSApp extends StatelessWidget {
  const CPSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPS Inventory',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}