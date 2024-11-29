// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'location_page.dart';
import 'scan_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _homeKey = GlobalKey<HomePageState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomePage(key: _homeKey),
      ScanPage(
        onScanSuccess: () {
          if (_homeKey.currentState != null) {
            _homeKey.currentState!.fetchItems();
          }
        },
      ),
      const LocationPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ]),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: NavigationBar(

            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inventory),
                label: 'Items',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_on),
                label: 'Locations',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
