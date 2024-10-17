import 'package:cps_dragonfly_4_mobile_app/pages/home_page.dart';
import 'package:cps_dragonfly_4_mobile_app/pages/scan_history_page.dart';
import 'package:cps_dragonfly_4_mobile_app/pages/scan_code_page.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/app_navigation_bar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CPS Dragonfly 4.0',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const ScanCodePage(),
    const ScanHistoryPage(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPS Dragonfly 4.0'),
        centerTitle: true,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index){
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}