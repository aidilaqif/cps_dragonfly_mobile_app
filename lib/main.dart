import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';  // Add this import
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Add this
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  runApp(const CPSApp());
}

class CPSApp extends StatelessWidget {
  const CPSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CPS Inventory',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Add localization support
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      home: const MainScreen(),
    );
  }
}