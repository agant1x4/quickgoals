import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/main app/intro_wizard.dart';
import '/main app/main_shell.dart';


void main() {
  // 1. Ensures core plugin services are locked in natively
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MaterialApp(
    home: AuthScreen(), // 2. Forces everyone to hit the login page first!
    debugShowCheckedModeBanner: false,
  ));
}



class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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
      // Saves credentials to SharedPreferences on signup
      await prefs.setString('local_email', _emailController.text.trim());
      await prefs.setString('local_username', _usernameController.text.trim());
      await prefs.setString('local_password', _passwordController.text);
    } else {
      // Verifies against saved credentials in SharedPreferences on login
      final savedEmail = prefs.getString('local_email') ?? '';
      final savedUsername = prefs.getString('local_username') ?? '';
      final savedPassword = prefs.getString('local_password') ?? '';
      final input = _emailController.text.trim();

      if ((input != savedEmail && input != savedUsername) ||
          _passwordController.text != savedPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid credentials or profile does not exist!',
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
    final size = MediaQuery.of(context).size;
    // Triggers only for screens wider than 800px and in landscape mode (desktops / tablets)
    final bool isDesktopLandscape = size.width > 800 && size.width > size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktopLandscape
          ? _buildDesktopLandscapeLayout(context)
          : _buildMobileLayout(context),
    );
  }

  /// Desktop / Tablet Landscape Layout (matches your reference screenshot)
  Widget _buildDesktopLandscapeLayout(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Side: Circular Artwork Container using auth_img.png
              Expanded(
                flex: 5,
                child: Center(
                  child: ClipOval(
                    child: SizedBox(
                      width: 440,
                      height: 440,
                      child: Image.asset(
                        'assets/auth_img.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),

              // Right Side: Typography & Form Fields
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Keep your head above water.',
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crush your goals.',
                          style: GoogleFonts.quicksand(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF8C42),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _isSignUpState
                              ? 'Sign up to Quickgoals'
                              : 'Sign in to Quickgoals',
                          style: GoogleFonts.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email / Username Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF8C42),
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w500,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'This field is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Username Field (Sign-up only)
                        if (_isSignUpState) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: GoogleFonts.quicksand(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF8C42),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w500,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please provide a username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF8C42),
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w500,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password cannot be empty';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Takeoff Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C42),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: _handleAuthAction,
                            child: Text(
                              'Takeoff',
                              style: GoogleFonts.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUpState = !_isSignUpState;
                                _formKey.currentState?.reset();
                              });
                            },
                            child: Text(
                              _isSignUpState
                                  ? 'Already have an account? Login'
                                  : 'Need an account? Sign up',
                              style: GoogleFonts.quicksand(
                                color: const Color(0xFF264653),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobile / Portrait Layout Fallback
  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/auth_img.png', fit: BoxFit.cover),
        ),
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
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w500),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'This field is strictly required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.w500),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please provide a registration username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
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
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w500),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password field cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
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
                          'Takeoff',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
    );
  }
}