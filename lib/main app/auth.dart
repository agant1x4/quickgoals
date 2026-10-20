import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intro_wizard.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Defaults straight to an optimized Sign Up view
  bool _isSignUpState = true;
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthAction() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();

    if (_isSignUpState) {
      // Local-first persistent storage writing block
      await prefs.setString('local_email', _emailController.text.trim());
      await prefs.setString('local_username', _usernameController.text.trim());
      await prefs.setString('local_password', _passwordController.text);
    } else {
      // Fetch persisted items to match existing local workspace profiles
      final savedEmail = prefs.getString('local_email') ?? '';
      final savedUsername = prefs.getString('local_username') ?? '';
      final savedPassword = prefs.getString('local_password') ?? '';
      final input = _emailController.text.trim();

      // Validation logic requiring either correct email or username match
      if ((input != savedEmail && input != savedUsername) ||
          _passwordController.text != savedPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid credentials or  profile does not exist!',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (mounted) {
      if (isFirstTime) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Layer utilizing your papercut sunset beach artwork texture
          Positioned.fill(
            child: Image.asset('assets/image_bd899e.jpg', fit: BoxFit.cover),
          ),

          // Header text stack positioned above the input drawer sheet block
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QuickGoals',
                  style: GoogleFonts.quicksand(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      const Shadow(
                        color: Colors.black38,
                        offset: Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUpState
                      ? 'Organize your workspace beautifully.'
                      : 'Welcome back to productivity.',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),

          // Grounded bottom drawer holding the interactive form fields
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 25,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Email/Credential Username input text field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: _isSignUpState
                              ? 'Email Address'
                              : 'Email or Username',
                          labelStyle: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          prefixIcon: const Icon(
                            Icons.alternate_email_rounded,
                            color: Color(0xFF264653),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF8C42),
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'This field is strictly required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Username input block rendered conditionally on Registration mode
                      if (_isSignUpState) ...[
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Unique Username',
                            labelStyle: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF264653),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF8C42),
                                width: 2,
                              ),
                            ),
                          ),
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w500,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide a registration username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Secure password toggle entry field space
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password Space',
                          labelStyle: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF264653),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF264653),
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF8C42),
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password field cannot be empty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Auth Execution Action Button with custom 30px curves
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C42),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _handleAuthAction,
                          child: Text(
                            _isSignUpState
                                ? 'Create Account'
                                : 'Sign In To Workspace',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic view status route action link modifier text
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUpState = !_isSignUpState;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isSignUpState
                              ? 'Missed the landing... Login Here'
                              : 'Lost in space... Signup Here',
                          style: GoogleFonts.quicksand(
                            color: const Color(0xFF264653),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
