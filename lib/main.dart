import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports mapped directly to your project structure
import 'main app/auth.dart';

void main() async {
  // Required to ensure plugin services like SharedPreferences are initialized before runApp
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  // If 'isFirstTime' doesn't exist, it defaults to true
  final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

  runApp(MyApp(isFirstTime: isFirstTime));
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;

  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickGoals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.quicksandTextTheme(Theme.of(context).textTheme),
      ),

      // Route flow: Launches into AuthScreen first.
      home: const AuthScreen(),
      // If user is onboarding for the first time, show intro wizard, otherwise go to MainShell.
    );
  }
}
