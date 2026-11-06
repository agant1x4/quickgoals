import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';



class QuickGoalsApp extends StatelessWidget {
  const QuickGoalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quickgoals',
      debugShowCheckedModeBanner: false,
      // Setting up your global theme with Quicksand font
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.quicksandTextTheme(Theme.of(context).textTheme),
      ),
      home: const MainGradientPage(),
    );
  }
}

class MainGradientPage extends StatelessWidget {
  const MainGradientPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // This creates your desktop-spanning sunset gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB), // Light Blue (Sky Blue)
              Color(0xFFFFDAB9), // Peach (Peach Puff)
            ],
            // Optional: add intermediate stops if you want to fine-tune the transition
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Placeholder for top-left branding
              Positioned(
                top: 40,
                left: 40,
                child: Text(
                  'Quickgoals',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 16, 16, 16),
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Center workspace area (Where your main dashboard/logic will live)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome to Quickgoals',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Desktop UI Initialized.',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
