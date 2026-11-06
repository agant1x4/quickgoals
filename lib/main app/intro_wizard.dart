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
      title: 'Quickgoals',
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
  // --- COLOR PALETTE & DESIGN TOKENS ---
  static const Color brandOrange = Color(0xFFFF8C42);
  static const Color brandBlue = Color(0xFF4A90E2);
  static const Color brandPurple = Color(0xFFB5A7E9);
  static const Color brandGreen = Color(0xFF48BB78);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textMuted = Color(0xFF718096);

  // Canonical 12 Pastel Palette
  static const List<Color> pastelPalette = [
    Color(0xFFFFB3BA),
    Color(0xFFFFDFBA),
    Color(0xFFFFFFBA),
    Color(0xFFBFFCC6),
    Color(0xFFB3F6F6),
    Color(0xFFBAE1FF),
    Color(0xFFD5AAFF),
    Color(0xFFF5B3F7),
    Color(0xFFE8EAED),
    Color(0xFFF1C0B9),
    Color(0xFFC7CEEA),
    Color(0xFFE2F0CB),
  ];

  // --- STATE VARIABLES ---
  int _currentStep = 0; // 0 to 5 for the 6 screens
  final int _totalSteps = 6;

  // Screen 2 (Moodle) State
  final TextEditingController _moodleUrlController =
      TextEditingController(text: 'https://www.winguacademy.co.za');
  final TextEditingController _moodleUserController = TextEditingController();
  final TextEditingController _moodlePassController = TextEditingController();
  bool _obscureMoodlePass = true;
  bool _isConnectingMoodle = false;
  String? _moodleConnectionError;

  // Screen 3 (Subjects) State
  final List<SubjectTaskData> _subjects = [];
  final TextEditingController _newSubjectController = TextEditingController();
  Color _newSubjectColor = pastelPalette[0];

  // Screen 4 (Workload) State
  int _workloadSubjectIndex = 0;

  // Screen 6 (Productivity Rhythm) State
  final Set<String> _selectedStudyWindows = {'Morning'};
  final Set<String> _selectedFocusDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  };
  String _selectedStrategy = 'Ice Cream';

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
    _newSubjectController.dispose();
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
          });
        }
      }
    } catch (e) {
      debugPrint('[IntroWizard] Cache preload skipped: $e');
    }
  }

  // --- NAVIGATION CONTROLLERS ---
  void _nextStep() {
    if (_currentStep == 2 && _subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least one subject to proceed!',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: brandOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        if (_currentStep == 3) {
          _workloadSubjectIndex = 0;
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  // --- SCREEN 2: MOODLE AUTH & IMPORT ---
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
            _subjects.addAll(imported);
            _isConnectingMoodle = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully imported ${_subjects.length} courses! 🎉',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
              ),
              backgroundColor: brandGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );

          _nextStep();
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
      });
    }
    _nextStep();
  }

  // --- SCREEN 3: SUBJECT MANAGEMENT ---
  void _addNewSubject() {
    final title = _newSubjectController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _subjects.add(
        SubjectTaskData(
          name: title,
          customName: title,
          subjectColor: _newSubjectColor,
          lessonDifficulty: 3,
          quizDifficulty: 3,
          assignmentDifficulty: 3,
          taskList: [],
        ),
      );
      _newSubjectController.clear();
      _newSubjectColor =
          pastelPalette[(_subjects.length) % pastelPalette.length];
    });
  }

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
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: textMuted,
                ),
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
                labelText: 'Friendly Display Name',
                labelStyle: GoogleFonts.quicksand(color: textMuted),
                filled: true,
                fillColor: const Color(0xFFF7FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: brandOrange, width: 1.5),
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

  // --- SCREEN 5: EXAM DATE PICKER ---
  Future<void> _pickExamDate(SubjectTaskData subject) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: subject.examDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: brandOrange,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        subject.examDate = picked;

        // Auto-enqueue or update high-stakes exam task item in subject
        final examTitle = '${subject.displayName} Final Exam';
        final existingIndex = subject.taskList.indexWhere(
          (t) => t.isExam || t.title.toLowerCase().contains('final exam'),
        );

        if (existingIndex != -1) {
          subject.taskList[existingIndex] = subject.taskList[existingIndex].copyWith(
            dueDate: DateTime(picked.year, picked.month, picked.day, 23, 59),
            isExam: true,
            difficulty: 5,
            load: TaskLoad.melting,
          );
        } else {
          subject.taskList.add(
            TaskItem(
              id: 'exam_${subject.name.hashCode}_${picked.millisecondsSinceEpoch}',
              title: examTitle,
              type: 'Exam',
              description: 'Major cumulative exam commitment.',
              difficulty: 5,
              load: TaskLoad.melting,
              dueDate: DateTime(picked.year, picked.month, picked.day, 23, 59),
              durationMinutes: 120,
              isExam: true,
              subjectName: subject.name,
            ),
          );
        }
      });
    }
  }

  // --- SCREEN 6: FINALIZE & PERSIST ---
  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      // Persist Subjects
      final encodedSubjects = jsonEncode(
        _subjects.map((s) => s.toMap()).toList(),
      );
      await prefs.setString('quickgoals_user_subjects', encodedSubjects);
      await prefs.setString('workspace_subjects_data', encodedSubjects);

      // Persist Strategy
      await prefs.setString('currentWorkstyle', _selectedStrategy);

      // Persist Productivity Profile
      final profile = ProductivityProfile(
        studyWindows: _selectedStudyWindows.toList(),
        bestDays: _selectedFocusDays.toList(),
        strategy: _selectedStrategy,
        dailyCapacityCap: 30.0,
        studentArchetype: _getArchetypeTitle(),
      );
      await prefs.setString(
        'quickgoals_productivity_profile',
        jsonEncode(profile.toMap()),
      );
    } catch (e) {
      debugPrint('[IntroWizard] Error writing local state: $e');
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
            'Welcome to Quickgoals! Your profile is ready. ✨',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: brandPurple,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getArchetypeTitle() {
    final bool hasMorning = _selectedStudyWindows.contains('Morning');
    final bool hasNight = _selectedStudyWindows.contains('Night');

    if (hasMorning && _selectedStrategy == 'Ice Cream') {
      return 'The Agile Morning Strategist';
    } else if (hasMorning && _selectedStrategy == 'Skyscraper') {
      return 'The High-Altitude Peak Achiever';
    } else if (hasNight) {
      return 'The Nocturnal Deep-Focus Scholar';
    } else if (_selectedStrategy == 'Battleship') {
      return 'The Tactical Deadline Defender';
    } else {
      return 'The Serene Balanced Explorer';
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  _buildTopProgressBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: _buildStepContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProgressBar() {
    final double progress = (_currentStep + 1) / _totalSteps;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              IconButton(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: textDark,
                visualDensity: VisualDensity.compact,
                tooltip: 'Back',
              )
            else
              const SizedBox(width: 32),
            Text(
              'Step ${_currentStep + 1} of $_totalSteps',
              style: GoogleFonts.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(brandOrange),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildScreen1Welcome();
      case 1:
        return _buildScreen2ConnectMoodle();
      case 2:
        return _buildScreen3Subjects();
      case 3:
        return _buildScreen4Workload();
      case 4:
        return _buildScreen5Commitments();
      case 5:
        return _buildScreen6RhythmAndProfile();
      default:
        return _buildScreen1Welcome();
    }
  }

  // ==========================================
  // SCREEN 1: WELCOME & PHILOSOPHY
  // ==========================================
  Widget _buildScreen1Welcome() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 88,
            height: 88,
            decoration: ShapeDecoration(
              color: brandOrange.withValues(alpha: 0.12),
              shape: const FigmaSmoothRectBorder(radius: 28, smoothing: 0.6),
            ),
            alignment: Alignment.center,
            child: const Text('✨', style: TextStyle(fontSize: 42)),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Quickgoals',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Break study inertia, balance your cognitive load,\nand organize your semester with serene clarity.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
          _buildPillarCard(
            emoji: '🧘',
            title: 'Burnout Soft Cap',
            desc:
                'Avoid mental crashes. We monitor daily cognitive load so you stay within healthy limits.',
          ),
          const SizedBox(height: 12),
          _buildPillarCard(
            emoji: '🍦',
            title: 'Momentum Pacing',
            desc:
                'Overcome procrastination by sequencing tasks by natural energy instead of guilt.',
          ),
          const SizedBox(height: 12),
          _buildPillarCard(
            emoji: '🔄',
            title: 'LMS Harmony',
            desc:
                'Synchronize assignments, lessons, and exam deadlines directly from your courses.',
          ),
          const SizedBox(height: 36),
          _buildPrimaryButton(
            title: 'Begin Setup',
            color: brandBlue,
            onPressed: _nextStep,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPillarCard({
    required String emoji,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const FigmaSmoothRectBorder(
          radius: 20,
          smoothing: 0.6,
          side: BorderSide(color: Color(0xFFEDF2F7)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: const Color(0xFFF7FAFC),
              shape: const FigmaSmoothRectBorder(radius: 14, smoothing: 0.6),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 2: CONNECT ACADEMIC LIFE (MOODLE)
  // ==========================================
  Widget _buildScreen2ConnectMoodle() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Connect Academic Life',
            style: GoogleFonts.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Link your Moodle LMS to automatically import active courses and pending deadlines.',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              color: textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: const FigmaSmoothRectBorder(
                radius: 24,
                smoothing: 0.6,
                side: BorderSide(color: Color(0xFFEDF2F7)),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: ShapeDecoration(
                        color: brandOrange.withValues(alpha: 0.15),
                        shape: const FigmaSmoothRectBorder(
                          radius: 12,
                          smoothing: 0.6,
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: brandOrange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Wingu Academy / Moodle Portal',
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _moodleUserController,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Student Username / ID',
                    labelStyle: GoogleFonts.quicksand(color: textMuted),
                    hintText: 'e.g., student.name',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: brandOrange, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _moodlePassController,
                  obscureText: _obscureMoodlePass,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _connectAndImportMoodle(),
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Portal Password',
                    labelStyle: GoogleFonts.quicksand(color: textMuted),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureMoodlePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureMoodlePass = !_obscureMoodlePass;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: brandOrange, width: 1.5),
                    ),
                  ),
                ),
                if (_moodleConnectionError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _moodleConnectionError!,
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              color: Colors.redAccent[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isConnectingMoodle ? null : _connectAndImportMoodle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandOrange,
                      elevation: 0,
                      shape: const FigmaSmoothRectBorder(
                        radius: 20,
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
                            'Connect & Import Courses',
                            style: GoogleFonts.quicksand(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _skipMoodleManualSetup,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: textMuted,
              ),
              label: Text(
                'Skip for now (Set up manually)',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 3: YOUR SUBJECTS (RENAME & THEMES)
  // ==========================================
  Widget _buildScreen3Subjects() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Subjects',
          style: GoogleFonts.quicksand(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Review imported courses, personalize friendly names, and assign theme pastels.',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 18),
        // Add new subject bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSubjectController,
                onSubmitted: (_) => _addNewSubject(),
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Add custom subject (e.g. Chemistry)',
                  hintStyle: GoogleFonts.quicksand(color: textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFEDF2F7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFEDF2F7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: brandOrange, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _addNewSubject,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 50,
                height: 50,
                decoration: ShapeDecoration(
                  color: brandOrange,
                  shape:
                      const FigmaSmoothRectBorder(radius: 16, smoothing: 0.6),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Palette Selector
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pastelPalette.length,
            itemBuilder: (context, idx) {
              final color = pastelPalette[idx];
              final isSelected = _newSubjectColor == color;
              return GestureDetector(
                onTap: () => setState(() => _newSubjectColor = color),
                child: Container(
                  width: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? textDark : Colors.transparent,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: textDark)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Subjects List
        Expanded(
          child: _subjects.isEmpty
              ? Center(
                  child: Text(
                    'No subjects yet. Type above to add your first subject!',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: const FigmaSmoothRectBorder(
                          radius: 18,
                          smoothing: 0.6,
                          side: BorderSide(color: Color(0xFFEDF2F7)),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Cycle next color in palette
                              setState(() {
                                final currentIndex = pastelPalette.indexWhere(
                                  (c) =>
                                      c.toARGB32() ==
                                      subject.subjectColor.toARGB32(),
                                );
                                final nextColor = pastelPalette[
                                    (currentIndex + 1) % pastelPalette.length];
                                _subjects[index] = SubjectTaskData(
                                  name: subject.name,
                                  customName: subject.customName,
                                  subjectColor: nextColor,
                                  lessonDifficulty: subject.lessonDifficulty,
                                  quizDifficulty: subject.quizDifficulty,
                                  assignmentDifficulty:
                                      subject.assignmentDifficulty,
                                  examDate: subject.examDate,
                                  taskList: subject.taskList,
                                );
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: subject.subjectColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black12,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.palette_outlined,
                                size: 12,
                                color: textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.displayName,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                if (subject.customName != null &&
                                    subject.customName != subject.name)
                                  Text(
                                    'Course: ${subject.name}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: textMuted,
                            ),
                            onPressed: () => _showRenameDialog(index),
                            tooltip: 'Rename subject',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _subjects.removeAt(index);
                              });
                            },
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          title: 'Continue to Workload',
          color: brandBlue,
          onPressed: _nextStep,
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN 4: UNDERSTAND WORKLOAD (DIFFICULTIES)
  // ==========================================
  Widget _buildScreen4Workload() {
    if (_subjects.isEmpty) {
      return Center(
        child: Text(
          'Please add subjects first.',
          style: GoogleFonts.quicksand(fontSize: 14, color: textMuted),
        ),
      );
    }

    final safeIndex = _workloadSubjectIndex.clamp(0, _subjects.length - 1);
    final currentSubject = _subjects[safeIndex];

    return SingleChildScrollView(
      key: const ValueKey(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Understand Workload',
                style: GoogleFonts.quicksand(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${safeIndex + 1} of ${_subjects.length}',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: brandOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Calibrate base effort so new tasks adjust their cognitive weight automatically.',
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 18),
          // Active Subject Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ShapeDecoration(
              color: currentSubject.subjectColor.withValues(alpha: 0.25),
              shape: const FigmaSmoothRectBorder(radius: 18, smoothing: 0.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: currentSubject.subjectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentSubject.displayName,
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Sliders Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: const FigmaSmoothRectBorder(
                radius: 24,
                smoothing: 0.6,
                side: BorderSide(color: Color(0xFFEDF2F7)),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDifficultySliderRow(
                  label: 'Lessons Difficulty',
                  emoji: '📖',
                  value: currentSubject.lessonDifficulty,
                  onChanged: (val) {
                    setState(() => currentSubject.lessonDifficulty = val);
                  },
                ),
                const Divider(height: 28, color: Color(0xFFF0F4F8)),
                _buildDifficultySliderRow(
                  label: 'Quizzes Difficulty',
                  emoji: '✍️',
                  value: currentSubject.quizDifficulty,
                  onChanged: (val) {
                    setState(() => currentSubject.quizDifficulty = val);
                  },
                ),
                const Divider(height: 28, color: Color(0xFFF0F4F8)),
                _buildDifficultySliderRow(
                  label: 'Assignments Difficulty',
                  emoji: '💻',
                  value: currentSubject.assignmentDifficulty,
                  onChanged: (val) {
                    setState(() => currentSubject.assignmentDifficulty = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (safeIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _workloadSubjectIndex--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E0)),
                      shape: const FigmaSmoothRectBorder(
                        radius: 20,
                        smoothing: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Previous',
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ),
                ),
              if (safeIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  title: safeIndex < _subjects.length - 1
                      ? 'Next Subject'
                      : 'Save & Continue',
                  color: brandOrange,
                  onPressed: () {
                    if (safeIndex < _subjects.length - 1) {
                      setState(() {
                        _workloadSubjectIndex++;
                      });
                    } else {
                      _nextStep();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySliderRow({
    required String label,
    required String emoji,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    String descriptor = 'Moderate';
    if (value == 1) descriptor = 'Breeze 🍃';
    if (value == 2) descriptor = 'Light 🟢';
    if (value == 3) descriptor = 'Balanced ⚖️';
    if (value == 4) descriptor = 'Challenging ⚡';
    if (value == 5) descriptor = 'High Intensity 🔥';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '$value / 5 • $descriptor',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: brandOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: brandOrange,
            inactiveTrackColor: const Color(0xFFEDF2F7),
            thumbColor: brandOrange,
            trackHeight: 6,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: (val) => onChanged(val.toInt()),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN 5: UPCOMING COMMITMENTS (EXAMS)
  // ==========================================
  Widget _buildScreen5Commitments() {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Commitments',
          style: GoogleFonts.quicksand(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Lock in critical exam dates and term milestones so Quickgoals can reserve preparation windows.',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            color: textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _subjects.length,
            itemBuilder: (context, index) {
              final subject = _subjects[index];
              final hasExam = subject.examDate != null;
              final examDate = subject.examDate;
              final daysLeft = hasExam
                  ? examDate!.difference(DateTime.now()).inDays
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: const FigmaSmoothRectBorder(
                    radius: 20,
                    smoothing: 0.6,
                    side: BorderSide(color: Color(0xFFEDF2F7)),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: subject.subjectColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.displayName,
                            style: GoogleFonts.quicksand(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (hasExam)
                            Text(
                              'Exam: ${examDate!.day}/${examDate.month}/${examDate.year} • ${daysLeft != null && daysLeft >= 0 ? '$daysLeft days away' : 'Imminent'}',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: brandOrange,
                              ),
                            )
                          else
                            Text(
                              'No exam scheduled yet',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickExamDate(subject),
                      icon: Icon(
                        hasExam
                            ? Icons.event_available_outlined
                            : Icons.calendar_today_outlined,
                        size: 16,
                        color: hasExam ? brandOrange : textDark,
                      ),
                      label: Text(
                        hasExam ? 'Change' : 'Set Date',
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasExam ? brandOrange : textDark,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasExam
                            ? brandOrange.withValues(alpha: 0.12)
                            : const Color(0xFFF7FAFC),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          title: 'Continue to Rhythm',
          color: brandBlue,
          onPressed: _nextStep,
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN 6: RHYTHM & PROFILE REVEAL
  // ==========================================
  Widget _buildScreen6RhythmAndProfile() {
    final archetype = _getArchetypeTitle();

    return SingleChildScrollView(
      key: const ValueKey(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productivity Rhythm',
            style: GoogleFonts.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select when you feel most energized and discover your student archetype.',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 18),

          // Peak Study Window
          Text(
            'Peak Study Windows:',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: '🌅 Morning (6am–12pm)',
                isSelected: _selectedStudyWindows.contains('Morning'),
                onSelected: (val) {
                  setState(() {
                    val
                        ? _selectedStudyWindows.add('Morning')
                        : _selectedStudyWindows.remove('Morning');
                    if (_selectedStudyWindows.isEmpty) {
                      _selectedStudyWindows.add('Morning');
                    }
                  });
                },
              ),
              _buildChoiceChip(
                label: '☀️ Afternoon (12pm–5pm)',
                isSelected: _selectedStudyWindows.contains('Afternoon'),
                onSelected: (val) {
                  setState(() {
                    val
                        ? _selectedStudyWindows.add('Afternoon')
                        : _selectedStudyWindows.remove('Afternoon');
                    if (_selectedStudyWindows.isEmpty) {
                      _selectedStudyWindows.add('Afternoon');
                    }
                  });
                },
              ),
              _buildChoiceChip(
                label: '🌙 Evening (5pm–10pm)',
                isSelected: _selectedStudyWindows.contains('Evening'),
                onSelected: (val) {
                  setState(() {
                    val
                        ? _selectedStudyWindows.add('Evening')
                        : _selectedStudyWindows.remove('Evening');
                    if (_selectedStudyWindows.isEmpty) {
                      _selectedStudyWindows.add('Evening');
                    }
                  });
                },
              ),
              _buildChoiceChip(
                label: '🦉 Night (10pm–2am)',
                isSelected: _selectedStudyWindows.contains('Night'),
                onSelected: (val) {
                  setState(() {
                    val
                        ? _selectedStudyWindows.add('Night')
                        : _selectedStudyWindows.remove('Night');
                    if (_selectedStudyWindows.isEmpty) {
                      _selectedStudyWindows.add('Night');
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Momentum Strategy
          Text(
            'Preferred Momentum Strategy:',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              _buildStrategyTile(
                name: 'Ice Cream',
                icon: '🍦',
                desc: 'Easiest tasks first to break inertia and build flow.',
              ),
              const SizedBox(height: 8),
              _buildStrategyTile(
                name: 'Skyscraper',
                icon: '🏢',
                desc: 'Tackle the heaviest cognitive challenges first.',
              ),
              const SizedBox(height: 8),
              _buildStrategyTile(
                name: 'Battleship',
                icon: '🚢',
                desc: 'Defend imminent deadlines and overdue milestones.',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dynamic Profile Reveal Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: const FigmaSmoothRectBorder(
                radius: 24,
                smoothing: 0.6,
                side: BorderSide(color: Color(0xFFEDF2F7)),
              ),
              shadows: [
                BoxShadow(
                  color: brandPurple.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: ShapeDecoration(
                        color: brandPurple.withValues(alpha: 0.15),
                        shape: const FigmaSmoothRectBorder(
                          radius: 14,
                          smoothing: 0.6,
                        ),
                      ),
                      child: const Text('🌟', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Student Archetype',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: brandPurple,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            archetype,
                            style: GoogleFonts.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryMetric(
                        title: 'Subjects',
                        value: '${_subjects.length}',
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE2E8F0),
                      ),
                      _buildSummaryMetric(
                        title: 'Exams Set',
                        value: '${_subjects.where((s) => s.examDate != null).length}',
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE2E8F0),
                      ),
                      _buildSummaryMetric(
                        title: 'Strategy',
                        value: _selectedStrategy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            title: 'Serenity Awaits',
            color: brandPurple,
            onPressed: _completeOnboarding,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({required String title, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 11,
            color: textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: brandOrange.withValues(alpha: 0.15),
      checkmarkColor: brandOrange,
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.quicksand(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? brandOrange : textDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? brandOrange : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _buildStrategyTile({
    required String name,
    required String icon,
    required String desc,
  }) {
    final isSelected = _selectedStrategy == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedStrategy = name),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          color: isSelected
              ? brandOrange.withValues(alpha: 0.08)
              : Colors.white,
          shape: FigmaSmoothRectBorder(
            radius: 18,
            smoothing: 0.6,
            side: BorderSide(
              color: isSelected ? brandOrange : const Color(0xFFEDF2F7),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: brandOrange,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE PRIMARY BUTTON ---
  Widget _buildPrimaryButton({
    required String title,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: const FigmaSmoothRectBorder(
            radius: 26,
            smoothing: 0.6,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
