import 'package:cps_dragonfly_4_mobile_app/pages/home_page.dart';
import 'package:cps_dragonfly_4_mobile_app/pages/scan_code_page.dart';
import 'package:cps_dragonfly_4_mobile_app/pages/scan_history_page.dart';
import 'package:cps_dragonfly_4_mobile_app/services/database_service.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/app_navigation_bar.dart';
import 'package:postgres/postgres.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  try {
    final connection = await DatabaseService().connection;
    runApp(MyApp(connection: connection));
  } catch (e) {
    print('Failed to initialize database: $e');
    // Show error screen instead of crashing
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Database Connection Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Restart app
                    main();
                  },
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final PostgreSQLConnection connection;
  
  const MyApp({super.key, required this.connection});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CPS Dragonfly 4.0',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(connection: connection),
    );
  }
}

class MainScreen extends StatefulWidget {
  final PostgreSQLConnection connection;
  
  const MainScreen({super.key, required this.connection});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(connection: widget.connection),
      ScanCodePage(connection: widget.connection),
      ScanHistoryPage(connection: widget.connection),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'CPS Dragonfly 4.0',),
      body: _pages[_currentIndex],
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}