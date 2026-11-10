import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_shell.dart';
import '../models/task_models.dart';
import '../models/task_load.dart';
import '../services/moodle_service.dart';
import '../widgets/geometry.dart';

class QuickGoalsApp extends StatelessWidget {
  const QuickGoalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickGoals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFC),
        textTheme: GoogleFonts.quicksandTextTheme(),
      ),
      home: const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Brand color tokens
  static const Color brandOrange = Color(0xFFF7B154);
  static const Color brandOrangeAccent = Color(0xFFFF8C42);
  static const Color textDark = Color(0xFF1E242B);
  static const Color textMuted = Color(0xFF768294);
  static const Color canvasBg = Color(0xFFF9FAFC);

  // Canonical Pastel Palette & Strict Tonal Text Color Matrix
  static const List<Color> pastelPalette = [
    Color(0xFFFFB3BA), // Pastel Red/Pink
    Color(0xFFFFDFBA), // Pastel Orange/Peach
    Color(0xFFFFFFBA), // Pastel Yellow
    Color(0xFFBFFCC6), // Pastel Green
    Color(0xFFB3F6F6), // Pastel Teal
    Color(0xFFBAE1FF), // Pastel Blue
    Color(0xFFD5AAFF), // Pastel Purple
    Color(0xFFF5B3F7), // Pastel Magenta
    Color(0xFFE2F0CB), // Pastel Lime
  ];

  static Color getTonalTextColor(Color background) {
    final int value = background.toARGB32() & 0x00FFFFFF;
    switch (value) {
      case 0xFFB3BA: // Pastel Red/Pink
        return const Color(0xFF5C1D24); // Deep Maroon
      case 0xFFDFBA: // Pastel Orange/Peach
        return const Color(0xFF613307); // Deep Terracotta
      case 0xFFFFBA: // Pastel Yellow
        return const Color(0xFF524400); // Deep Olive Gold
      case 0xFFFCC6: // Pastel Green
        return const Color(0xFF0F4718); // Deep Forest Green
      case 0xB3F6F6: // Pastel Teal
        return const Color(0xFF004545); // Deep Midnight Teal
      case 0xBAE1FF: // Pastel Blue
        return const Color(0xFF0F3156); // Deep Royal Navy
      case 0xD5AAFF: // Pastel Purple
        return const Color(0xFF38145A); // Deep Royal Plum
      case 0xF5B3F7: // Pastel Magenta
        return const Color(0xFF541556); // Deep Dark Eggplant
      case 0xE2F0CB: // Pastel Lime
        return const Color(0xFF2E4011); // Deep Moss Green
      default:
        // Luminance-based safe fallback for any custom colors
        final luminance = background.computeLuminance();
        return luminance > 0.6 ? const Color(0xFF2C323C) : Colors.white;
    }
  }

  // State Engine: 0 = Screen 1 (Intro), 1 = Step 2 (Expandable Desktop Card Matrix), 2 = Step 3 (Time Allocation)
  int _currentStepIndex = 0;

  // Screen 1: Moodle authentication inputs
  final TextEditingController _moodleUrlController =
      TextEditingController(text: 'https://www.winguacademy.co.za');
  final TextEditingController _moodleUserController = TextEditingController();
  final TextEditingController _moodlePassController = TextEditingController();
  bool _obscureMoodlePass = true;
  bool _isConnectingMoodle = false;
  String? _moodleConnectionError;

  // Step 2 & 3: Subjects & Weekly Hours State
  final List<SubjectTaskData> _subjects = [];
  final Map<String, double> _weeklyHours = {}; // Raw aggregate weekly target hours (e.g. 14 hrs/week)
  final Set<int> _expandedCardIndices = {0}; // First card expanded by default

  @override
  void initState() {
    super.initState();
    _loadExistingCacheIfAvailable();
  }

  @override
  void dispose() {
    _moodleUrlController.dispose();
    _moodleUserController.dispose();
    _moodlePassController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCacheIfAvailable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString('quickgoals_user_subjects');
      if (cached != null && cached.isNotEmpty) {
        final List decoded = jsonDecode(cached);
        if (decoded.isNotEmpty && mounted) {
          setState(() {
            _subjects.clear();
            _subjects.addAll(
              decoded.map((item) => SubjectTaskData.fromMap(item)),
            );
            for (var subject in _subjects) {
              final savedHours = prefs.getDouble('weekly_hours_${subject.name}');
              _weeklyHours[subject.name] = savedHours ?? 10.0;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[IntroWizard] Cache preload skipped: $e');
    }
  }

  // --- SCREEN 1 -> STEP 1: AUTHENTICATION HANDSHAKE ---
  Future<void> _connectAndImportMoodle() async {
    final user = _moodleUserController.text.trim();
    final pass = _moodlePassController.text;
    final url = _moodleUrlController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _moodleConnectionError =
            'Please enter both Moodle student username and password.';
      });
      return;
    }

    setState(() {
      _isConnectingMoodle = true;
      _moodleConnectionError = null;
    });

    try {
      final token = await MoodleService.authenticateAndFetchToken(
        username: user,
        password: pass,
        portalUrl: url.isNotEmpty ? url : 'https://www.winguacademy.co.za',
      );

      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('moodle_user', user);
        await prefs.setString('moodle_pass', pass);
        await prefs.setString('moodle_token', token);

        final service = MoodleService(
          token: token,
          baseUrl: url.isNotEmpty ? url : 'https://www.winguacademy.co.za',
        );

        final imported = await service.fetchEnrolledSubjects(
          palette: pastelPalette,
        );

        if (mounted) {
          setState(() {
            _subjects.clear();
            if (imported.isNotEmpty) {
              _subjects.addAll(imported);
            } else {
              _subjects.addAll(MoodleService.generateFallbackSubjects(pastelPalette));
            }
            for (var s in _subjects) {
              _weeklyHours.putIfAbsent(s.name, () => 10.0);
            }
            _isConnectingMoodle = false;
            _currentStepIndex = 1; // Transition cleanly to Step 2 Card Matrix
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully connected! Loaded ${_subjects.length} subjects.',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0F4718),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isConnectingMoodle = false;
            _moodleConnectionError =
                'Authentication failed. Check your login credentials or network.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectingMoodle = false;
          _moodleConnectionError = 'Connection error: $e';
        });
      }
    }
  }

  void _skipMoodleManualSetup() {
    if (_subjects.isEmpty) {
      setState(() {
        _subjects.addAll(MoodleService.generateFallbackSubjects(pastelPalette));
        for (var s in _subjects) {
          _weeklyHours.putIfAbsent(s.name, () => 10.0);
        }
      });
    }
    setState(() {
      _currentStepIndex = 1;
    });
  }

  // --- FINALIZE ONBOARDING AND PERSIST ---
  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      final encodedSubjects = jsonEncode(
        _subjects.map((s) => s.toMap()).toList(),
      );
      await prefs.setString('quickgoals_user_subjects', encodedSubjects);
      await prefs.setString('workspace_subjects_data', encodedSubjects);

      for (var entry in _weeklyHours.entries) {
        await prefs.setDouble('weekly_hours_${entry.key}', entry.value);
      }

      final profile = const ProductivityProfile(
        studyWindows: ['Morning'],
        bestDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        strategy: 'Ice Cream',
        dailyCapacityCap: 30.0,
        studentArchetype: 'The Agile Morning Strategist',
      );
      await prefs.setString(
        'quickgoals_productivity_profile',
        jsonEncode(profile.toMap()),
      );
    } catch (e) {
      debugPrint('[IntroWizard] Error saving onboarding state: $e');
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome to QuickGoals! Your timetable matrix is calibrated. ✨',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF38145A),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // --- SUBJECT ACTIONS: RENAME, PALETTE CYCLE, DELETE ---
  void _showRenameDialog(int index) {
    final subject = _subjects[index];
    final controller = TextEditingController(text: subject.displayName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const FigmaSmoothRectBorder(radius: 24, smoothing: 0.6),
        title: Text(
          'Rename Subject',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.name != subject.displayName)
              Text(
                'Original course: ${subject.name}',
                style: GoogleFonts.quicksand(fontSize: 12, color: textMuted),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: GoogleFonts.quicksand(color: textMuted),
                filled: true,
                fillColor: const Color(0xFFF7FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: brandOrange, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  subject.customName = newName;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleSubjectColor(int index) {
    setState(() {
      final current = _subjects[index];
      final currentIndex = pastelPalette.indexWhere(
        (c) => (c.toARGB32() & 0x00FFFFFF) == (current.subjectColor.toARGB32() & 0x00FFFFFF),
      );
      final nextColor = pastelPalette[(currentIndex + 1) % pastelPalette.length];
      _subjects[index] = SubjectTaskData(
        name: current.name,
        customName: current.customName,
        subjectColor: nextColor,
        lessonDifficulty: current.lessonDifficulty,
        quizDifficulty: current.quizDifficulty,
        assignmentDifficulty: current.assignmentDifficulty,
        examDate: current.examDate,
        preferredStudyWindow: current.preferredStudyWindow,
        taskList: current.taskList,
      );
    });
  }

  void _deleteSubject(int index) {
    setState(() {
      final removed = _subjects.removeAt(index);
      _weeklyHours.remove(removed.name);
      _expandedCardIndices.remove(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _currentStepIndex == 0
              ? _buildScreen1Intro(context)
              : _buildStep2And3CardMatrix(context),
        ),
      ),
    );
  }

  // =========================================================================
  // SCREEN 1: INTRO SCREEN (ASYMMETRIC GRID LAYOUT WITH CHACMA STATE A)
  // =========================================================================
  Widget _buildScreen1Intro(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    return Center(
      key: const ValueKey('screen_1_intro'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Editorial Typography & Single-Pill Action Button
                    Expanded(
                      flex: 4,
                      child: _buildIntroEditorialColumn(),
                    ),
                    const SizedBox(width: 24),
                    // Center Anchor: Chacma State A (assets/chacma_bin.png)
                    Expanded(
                      flex: 3,
                      child: _buildChacmaAnchorStateA(),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: White Floating Card + High-Contrast Notification Card
                    Expanded(
                      flex: 5,
                      child: _buildMoodleFloatingCard(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIntroEditorialColumn(),
                    const SizedBox(height: 32),
                    _buildChacmaAnchorStateA(),
                    const SizedBox(height: 32),
                    _buildMoodleFloatingCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildIntroEditorialColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step 1:',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to\nMoodle',
          style: GoogleFonts.quicksand(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: textDark,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Set up to automatically pull your moodle tasks so that you can focus on actually completing activities.',
          style: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        // Asymmetric single-pill action button
        SizedBox(
          width: 175,
          height: 52,
          child: ElevatedButton(
            onPressed: _isConnectingMoodle ? null : _connectAndImportMoodle,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const FigmaSmoothRectBorder(
                radius: 26,
                smoothing: 0.6,
              ),
            ),
            child: _isConnectingMoodle
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Log in',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildChacmaAnchorStateA() {
    return Center(
      child: Image.asset(
        'assets/chacma_bin.png',
        fit: BoxFit.contain,
        height: 290,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 220,
            height: 250,
            decoration: ShapeDecoration(
              color: const Color(0xFFFFDFBA).withValues(alpha: 0.3),
              shape: const FigmaSmoothRectBorder(radius: 28, smoothing: 0.6),
            ),
            alignment: Alignment.center,
            child: const Text('🐒', style: TextStyle(fontSize: 72)),
          );
        },
      ),
    );
  }

  Widget _buildMoodleFloatingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const FigmaSmoothRectBorder(
          radius: 28,
          smoothing: 0.6,
          side: BorderSide(color: Color(0xFFEEF1F5), width: 1.2),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // High-contrast notification card matching Pastel Orange (0xFFFFDFBA) & Terracotta (0xFF613307)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: ShapeDecoration(
              color: const Color(0xFFFFDFBA),
              shape: const FigmaSmoothRectBorder(
                radius: 20,
                smoothing: 0.6,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF613307),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Note: Enter the exact details you enter into Moodle to be able to pull your specific activities.',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF613307),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Username Input Field wrapped in FigmaSmoothRectBorder
          Container(
            decoration: ShapeDecoration(
              color: const Color(0xFFF1F3F5),
              shape: const FigmaSmoothRectBorder(
                radius: 24,
                smoothing: 0.6,
              ),
            ),
            child: TextField(
              controller: _moodleUserController,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3C434F),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Password Input Field wrapped in FigmaSmoothRectBorder
          Container(
            decoration: ShapeDecoration(
              color: const Color(0xFFF1F3F5),
              shape: const FigmaSmoothRectBorder(
                radius: 24,
                smoothing: 0.6,
              ),
            ),
            child: TextField(
              controller: _moodlePassController,
              obscureText: _obscureMoodlePass,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _connectAndImportMoodle(),
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3C434F),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  padding: const EdgeInsets.only(right: 12),
                  icon: Icon(
                    _obscureMoodlePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureMoodlePass = !_obscureMoodlePass;
                    });
                  },
                ),
              ),
            ),
          ),
          if (_moodleConnectionError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _moodleConnectionError!,
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _skipMoodleManualSetup,
              child: Text(
                'Skip for now (Set up manually)',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2 & 3: EXPANDABLE DESKTOP CARD MATRIX WITH CHACMA STATE B
  // =========================================================================
  Widget _buildStep2And3CardMatrix(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1040;
    final isStep3 = _currentStepIndex == 2;

    return Center(
      key: ValueKey('step_matrix_$_currentStepIndex'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Step Metadata, Title, Description, Chacma State B & Asymmetric Button
                    SizedBox(
                      width: 320,
                      child: _buildMatrixLeftColumn(isStep3),
                    ),
                    const SizedBox(width: 48),
                    // Right Content: Two-Column Desktop Wrap Layout of Subject Cards
                    Expanded(
                      child: _buildMatrixCardsGrid(isStep3),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMatrixLeftColumn(isStep3),
                    const SizedBox(height: 32),
                    _buildMatrixCardsGrid(isStep3),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMatrixLeftColumn(bool isStep3) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  if (_currentStepIndex == 2) {
                    _currentStepIndex = 1;
                  } else {
                    _currentStepIndex = 0;
                  }
                });
              },
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              color: textDark,
              visualDensity: VisualDensity.compact,
              tooltip: 'Back',
            ),
            Text(
              isStep3 ? 'Step 3:' : 'Step 2:',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isStep3 ? 'Allocate Weekly\nTarget Budget' : 'Manage your\nSubjects',
          style: GoogleFonts.quicksand(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: textDark,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isStep3
              ? 'Calibrate your raw aggregate weekly target study hours for each subject to keep your study schedule dynamic and fluid.'
              : 'Verify if the subjects pulled from moodle are yours, customise the colours and set a base difficulty for your activities by tapping each card.',
          style: GoogleFonts.quicksand(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        // Asymmetric Action Button
        SizedBox(
          width: 175,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (!isStep3) {
                // Move from Step 2 to Step 3 (Weekly Budget Extension View)
                setState(() {
                  _currentStepIndex = 2;
                });
              } else {
                // Finalize onboarding
                _completeOnboarding();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const FigmaSmoothRectBorder(
                radius: 26,
                smoothing: 0.6,
              ),
            ),
            child: Text(
              isStep3 ? 'Get Started' : 'Its perfect',
              style: GoogleFonts.quicksand(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Chacma State B: Mount on Step 2 through final wizard screens dynamically next to config modules
        Center(
          child: Image.asset(
            'assets/chacma_painting.png',
            height: 210,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 170,
                height: 170,
                decoration: ShapeDecoration(
                  color: brandOrange.withValues(alpha: 0.15),
                  shape: const FigmaSmoothRectBorder(radius: 24, smoothing: 0.6),
                ),
                alignment: Alignment.center,
                child: const Text('🎨', style: TextStyle(fontSize: 54)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixCardsGrid(bool isStep3) {
    if (_subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No subjects imported. Return to Step 1 or click "Its perfect" to generate fallback courses.',
            style: GoogleFonts.quicksand(fontSize: 16, color: textMuted),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop two-column layout when width allows, otherwise single column
        final useTwoColumns = constraints.maxWidth >= 640;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 20,
          runSpacing: 16,
          children: List.generate(_subjects.length, (index) {
            return SizedBox(
              width: cardWidth,
              child: _buildExpandableSubjectCard(index, isStep3),
            );
          }),
        );
      },
    );
  }

  Widget _buildExpandableSubjectCard(int index, bool isStep3) {
    final subject = _subjects[index];
    final isExpanded = _expandedCardIndices.contains(index);
    final cardBgColor = subject.subjectColor;
    final cardTextColor = getTonalTextColor(cardBgColor);

    return Container(
      decoration: ShapeDecoration(
        color: cardBgColor,
        shape: const FigmaSmoothRectBorder(
          radius: 26,
          smoothing: 0.6,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCardIndices.remove(index);
              } else {
                _expandedCardIndices.add(index);
              }
            });
          },
          customBorder: const FigmaSmoothRectBorder(
            radius: 26,
            smoothing: 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row: Friendly Title & Micro-Circle Cluster
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject.displayName,
                        style: GoogleFonts.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: cardTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Micro-Circle Cluster: Edit, Palette, Delete
                    _buildMicroCircleButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Rename',
                      textColor: cardTextColor,
                      onTap: () => _showRenameDialog(index),
                    ),
                    const SizedBox(width: 6),
                    _buildMicroCircleButton(
                      icon: Icons.palette_outlined,
                      tooltip: 'Cycle Color Theme',
                      textColor: cardTextColor,
                      onTap: () => _cycleSubjectColor(index),
                    ),
                    const SizedBox(width: 6),
                    _buildMicroCircleButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete Subject',
                      textColor: cardTextColor,
                      onTap: () => _deleteSubject(index),
                    ),
                  ],
                ),
                // Smooth Clip-Masked Animated Transition for Inline Shelf
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: isExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: ShapeDecoration(
                                color: Colors.white.withValues(alpha: 0.45),
                                shape: const FigmaSmoothRectBorder(
                                  radius: 20,
                                  smoothing: 0.6,
                                ),
                              ),
                              child: isStep3
                                  ? _buildWeeklyBudgetInlineShelf(subject, cardTextColor)
                                  : _buildDifficultiesInlineShelf(subject, cardTextColor),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicroCircleButton({
    required IconData icon,
    required String tooltip,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.40),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // --- STEP 2 INLINE SHELF: DIFFICULTY PARAMETERS ---
  Widget _buildDifficultiesInlineShelf(SubjectTaskData subject, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDifficultyDropdownRow(
          title: 'Lessons',
          value: subject.lessonDifficulty,
          textColor: textColor,
          onChanged: (val) {
            setState(() {
              subject.lessonDifficulty = val;
            });
          },
        ),
        const SizedBox(height: 10),
        _buildDifficultyDropdownRow(
          title: 'Quizes',
          value: subject.quizDifficulty,
          textColor: textColor,
          onChanged: (val) {
            setState(() {
              subject.quizDifficulty = val;
            });
          },
        ),
        const SizedBox(height: 10),
        _buildDifficultyDropdownRow(
          title: 'Worksheets and assignments',
          value: subject.assignmentDifficulty,
          textColor: textColor,
          onChanged: (val) {
            setState(() {
              subject.assignmentDifficulty = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDifficultyDropdownRow({
    required String title,
    required int value,
    required Color textColor,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        // Styled selection pill with FigmaSmoothRectBorder
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: ShapeDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            shape: const FigmaSmoothRectBorder(
              radius: 12,
              smoothing: 0.6,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor),
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              items: [1, 2, 3, 4, 5].map((lvl) {
                return DropdownMenuItem<int>(
                  value: lvl,
                  child: Text(
                    '$lvl',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 3 INLINE SHELF: WEEKLY TOTAL HOURS BUDGET TARGET ---
  Widget _buildWeeklyBudgetInlineShelf(SubjectTaskData subject, Color textColor) {
    final double hours = _weeklyHours[subject.name] ?? 10.0;
    final int hoursInt = hours.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Total Hours Target',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            // Explicit raw aggregate weekly target metric (e.g. 14 hrs / week)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                shape: const FigmaSmoothRectBorder(
                  radius: 12,
                  smoothing: 0.6,
                ),
              ),
              child: Text(
                '$hoursInt hrs / week',
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: textColor.withValues(alpha: 0.85),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.50),
            thumbColor: textColor,
            trackHeight: 5,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: hours.clamp(1.0, 40.0),
            min: 1.0,
            max: 40.0,
            divisions: 39,
            onChanged: (val) {
              setState(() {
                _weeklyHours[subject.name] = val;
              });
            },
          ),
        ),
      ],
    );
  }
}
