import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickgoals_flutter/main%20app/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_shell.dart'; // Ensure this contains your actual DashboardScreen and SubjectTaskData definition
import '../models/task_models.dart';

void main() {
  runApp(const QuickGoalsApp());
}

class QuickGoalsApp extends StatelessWidget {
  const QuickGoalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quickgoals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
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
  // --- DESIGN CONSTANTS ---
  final Color buttonBlue = const Color(0xFF4A90E2);
  final Color buttonOrange = const Color(0xFFFF8C42);
  final Color buttonPurple = const Color(0xFFB5A7E9);

  // --- 12 PASTEL COLORS SELECTION ARRAY (Kept Exactly as Requested!) ---
  final List<Color> pastelPalette = const [
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

  late Color _selectedColor;

  // --- STATE VARIABLES ---
  // Updated to use your app's global SubjectTaskData model so data shares automatically
  final List<SubjectTaskData> _subjects = [];
  final TextEditingController _subjectController = TextEditingController();

  int _wizardStep =
      0; // 0: Subjects & Colors, 1: Difficulties, 2: Final Summary
  int _currentRatingSubjectIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedColor = pastelPalette[0];
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  void _addSubject() {
    final name = _subjectController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _subjects.add(
          SubjectTaskData(
            name: name,
            subjectColor: _selectedColor,
            lessonDifficulty: 3,
            quizDifficulty: 3,
            assignmentDifficulty: 3,
            taskList: [],
          ),
        );
        _subjectController.clear();
        _selectedColor =
            pastelPalette[(_subjects.length) % pastelPalette.length];
      });
    }
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  void _goToNextStep() {
    if (_wizardStep == 0) {
      if (_subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please add at least one subject to proceed!"),
            backgroundColor: Colors.black87,
          ),
        );
        return;
      }
      setState(() {
        _wizardStep = 1;
        _currentRatingSubjectIndex = 0;
      });
    } else if (_wizardStep == 1) {
      if (_currentRatingSubjectIndex < _subjects.length - 1) {
        setState(() {
          _currentRatingSubjectIndex++;
        });
      } else {
        setState(() {
          _wizardStep = 2;
        });
      }
    }
  }

  void _goBack() {
    if (_wizardStep == 1) {
      if (_currentRatingSubjectIndex > 0) {
        setState(() {
          _currentRatingSubjectIndex--;
        });
      } else {
        setState(() {
          _wizardStep = 0;
        });
      }
    } else if (_wizardStep == 2) {
      setState(() {
        _wizardStep = 1;
        _currentRatingSubjectIndex = _subjects.length - 1;
      });
    }
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'QuickGoals',
                style: GoogleFonts.quicksand(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[850],
                  letterSpacing: -1.0,
                ),
              ),
              Text(
                'Balance your study calendar effortlessly.',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildWizardContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardContent() {
    switch (_wizardStep) {
      case 0:
        return _buildSubjectInputStep();
      case 1:
        return _buildDifficultyRatingStep();
      case 2:
        return _buildCompletionStep();
      default:
        return _buildSubjectInputStep();
    }
  }

  Widget _buildSubjectInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: buttonOrange,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Prepare your timetable',
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[850],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _subjectController,
                  onSubmitted: (_) => _addSubject(),
                  decoration: InputDecoration(
                    hintText: 'e.g., MATH101, GEOG201',
                    hintStyle: GoogleFonts.quicksand(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: buttonOrange, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _addSubject,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Pick Theme Color for Subject:',
          style: GoogleFonts.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pastelPalette.length,
            itemBuilder: (context, index) {
              final color = pastelPalette[index];
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.grey[850]! : Colors.grey[200]!,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: Colors.grey[850])
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _subjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No subjects added yet.',
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final item = _subjects[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: _panelDecoration(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: item.subjectColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.name,
                                style: GoogleFonts.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            onPressed: () => _removeSubject(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              'Next',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyRatingStep() {
    final currentSubject = _subjects[_currentRatingSubjectIndex];
    final progressPercentage =
        (_currentRatingSubjectIndex + 1) / _subjects.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _goBack,
              icon: const Icon(
                Icons.arrow_back,
                size: 16,
                color: Colors.black54,
              ),
              label: Text(
                'Back',
                style: GoogleFonts.quicksand(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_currentRatingSubjectIndex + 1}/${_subjects.length}',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progressPercentage,
          backgroundColor: Colors.grey[100],
          color: buttonOrange,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 20),
        Text(
          'Set difficulty details for:',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: currentSubject.subjectColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              currentSubject.name,
              style: GoogleFonts.quicksand(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _panelDecoration(),
            child: ListView(
              children: [
                _buildRatingSlider(
                  'Lessons Difficulty',
                  currentSubject.lessonDifficulty,
                  (val) =>
                      setState(() => currentSubject.lessonDifficulty = val),
                ),
                const SizedBox(height: 20),
                _buildRatingSlider(
                  'Quizzes Difficulty',
                  currentSubject.quizDifficulty,
                  (val) => setState(() => currentSubject.quizDifficulty = val),
                ),
                const SizedBox(height: 20),
                _buildRatingSlider(
                  'Assignments Difficulty',
                  currentSubject.assignmentDifficulty,
                  (val) =>
                      setState(() => currentSubject.assignmentDifficulty = val),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              _currentRatingSubjectIndex < _subjects.length - 1
                  ? 'Next Subject'
                  : 'Save Details',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSlider(
    String title,
    int currentValue,
    Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: buttonOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$currentValue / 5',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: buttonOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: buttonOrange,
            inactiveTrackColor: Colors.grey[100],
            thumbColor: buttonOrange,
            trackHeight: 5,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: currentValue.toDouble(),
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: (double val) => onChanged(val.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to Organize',
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[850],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Text(
                    'Configurations built successfully. Let\'s step inside your optimized dashboard views.',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Configured Summary (${_subjects.length})',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ..._subjects.map(
                  (sub) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: _panelDecoration(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: sub.subjectColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              sub.name,
                              style: GoogleFonts.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[850],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'L:${sub.lessonDifficulty} • Q:${sub.quizDifficulty} • A:${sub.assignmentDifficulty}',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _goBack,
            child: Text(
              'Edit Data',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () async {
              // --- FIXED STATE PERSISTENCE INJECTION ---
              // This encodes the subjects mapped by the onboarding step exactly how the Settings and Dashboard screens look for them
              try {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setBool('isFirstTime', false);

                final String encodedSubjects = jsonEncode(
                  _subjects.map((s) => s.toMap()).toList(),
                );
                await prefs.setString(
                  'quickgoals_user_subjects',
                  encodedSubjects,
                );
              } catch (e) {
                debugPrint("Error writing local state cache: $e");
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
                      "Welcome to your dashboard!",
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: buttonPurple,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonPurple,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              'Serenity awaits',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
