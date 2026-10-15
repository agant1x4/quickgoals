import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_phone.dart';
import 'pomodoro.dart';
import '../models/task_models.dart';
import '../services/moodle_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = 'Alex Mercer';
  String _userEmail = 'alex.mercer@school.edu';
  List<SubjectTaskData> _subjects = [];
  String _activeView =
      'main'; // Views: 'main', 'account', 'subjects', 'pomodoro_settings'
  String _activeAccountForm =
      'details'; // Forms: 'details' (Personal info) or 'moodle' (LMS configurations)

  // Controllers for account details modification
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editPasswordController = TextEditingController();

  // Controllers for Moodle Sync
  final TextEditingController _moodleIdentifierController =
      TextEditingController();
  final TextEditingController _moodlePasswordController =
      TextEditingController();
  bool _isAutoAddMode = false;
  bool _isAuthenticating = false;

  // Brand Palette Matching Your Orange/Pastel Figma Wireframes
  final Color brandOrange = const Color(0xFFFF8C42);
  final Color backgroundColor = const Color(0xFFF4F5F8);
  final Color cardColor = Colors.white;

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editEmailController.dispose();
    _editPasswordController.dispose();
    _moodleIdentifierController.dispose();
    _moodlePasswordController.dispose();
    super.dispose();
  }

  void _loadSettings() async {
    final storage = await SharedPreferences.getInstance();

    final name =
        storage.getString('local_username') ??
        storage.getString('quickgoals_user_name') ??
        'Alex Mercer';
    final email =
        storage.getString('local_email') ??
        storage.getString('quickgoals_user_email') ??
        'alex.mercer@school.edu';
    final subjectsJson =
        storage.getString('quickgoals_user_subjects') ??
        storage.getString('workspace_subjects_data');

    // Retrieve Saved Moodle Credentials
    _moodleIdentifierController.text = storage.getString('moodle_user') ?? '';
    _moodlePasswordController.text = storage.getString('moodle_pass') ?? '';
    _isAutoAddMode = storage.getBool('moodle_auto_add') ?? false;

    _editNameController.text = name;
    _editEmailController.text = email;

    setState(() {
      _userName = name;
      _userEmail = email;
      if (subjectsJson != null && subjectsJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(subjectsJson);
          _subjects = decoded
              .map(
                (item) => SubjectTaskData.fromMap(item as Map<String, dynamic>),
              )
              .toList();
        } catch (_) {}
      }
    });
  }

  void _saveSettings() async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString('quickgoals_user_name', _userName);
    await storage.setString('local_username', _userName);
    await storage.setString('quickgoals_user_email', _userEmail);
    await storage.setString('local_email', _userEmail);
    final String encoded = jsonEncode(_subjects.map((s) => s.toMap()).toList());
    await storage.setString('quickgoals_user_subjects', encoded);
    await storage.setString('workspace_subjects_data', encoded);
  }

  void _saveMoodleCredentials() async {
    final storage = await SharedPreferences.getInstance();
    final username = _moodleIdentifierController.text.trim();
    final password = _moodlePasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter both Moodle Username and Password!',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logging in to Wingu Academy portal securely...'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Handshake and trade credentials directly for a perfectly configured web service token
    final String? obtainedToken = await MoodleService.authenticateAndFetchToken(
      username: username,
      password: password,
    );

    setState(() {
      _isAuthenticating = false;
    });

    if (obtainedToken != null && obtainedToken.isNotEmpty) {
      // Save credentials and dynamic authorization token in storage slots
      await storage.setString('moodle_user', username);
      await storage.setString('moodle_pass', password);
      await storage.setString('moodle_token', obtainedToken);
      await storage.setBool('moodle_auto_add', _isAutoAddMode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully connected to Wingu Academy! 🎉',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _activeView = 'main');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login failed! Please check your credentials or network.',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddSubjectDialog() {
    String newName = '';
    Color chosenColor = pastelPalette[0];
    double lessonDiff = 3;
    double quizDiff = 3;
    double assignDiff = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'New Subject Folder 📚',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Subject Name',
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF8C42)),
                    ),
                  ),
                  onChanged: (val) => newName = val,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pick Theme Color:',
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: pastelPalette.map((color) {
                    final isSelected = chosenColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => chosenColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.black87
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Lesson Difficulty: ${lessonDiff.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: lessonDiff,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => lessonDiff = v),
                ),
                Text(
                  'Quiz Difficulty: ${quizDiff.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: quizDiff,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => quizDiff = v),
                ),
                Text(
                  'Assignment Difficulty: ${assignDiff.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: assignDiff,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => assignDiff = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandOrange),
              onPressed: () {
                if (newName.trim().isNotEmpty) {
                  setState(() {
                    _subjects.add(
                      SubjectTaskData(
                        name: newName.trim(),
                        subjectColor: chosenColor,
                        lessonDifficulty: lessonDiff.round(),
                        quizDifficulty: quizDiff.round(),
                        assignmentDifficulty: assignDiff.round(),
                        taskList: [],
                      ),
                    );
                  });
                  _saveSettings();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubjectDetailEditor(SubjectTaskData subject) {
    double lesson = subject.lessonDifficulty.toDouble();
    double quiz = subject.quizDifficulty.toDouble();
    double assign = subject.assignmentDifficulty.toDouble();
    double motivation = subject.motivationLevel.toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Configure ${subject.name} ⚙️',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lesson Difficulty: ${lesson.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: lesson,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => lesson = v),
                ),
                Text(
                  'Quiz Difficulty: ${quiz.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: quiz,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => quiz = v),
                ),
                Text(
                  'Assignment Difficulty: ${assign.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: assign,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => assign = v),
                ),
                Text(
                  'Motivation Level: ${motivation.round()}',
                  style: GoogleFonts.quicksand(fontSize: 12),
                ),
                Slider(
                  value: motivation,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: brandOrange,
                  onChanged: (v) => setDialogState(() => motivation = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _subjects.remove(subject);
                });
                _saveSettings();
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  subject.lessonDifficulty = lesson.round();
                  subject.quizDifficulty = quiz.round();
                  subject.assignmentDifficulty = assign.round();
                  subject.motivationLevel = motivation.round();
                });
                _saveSettings();
                Navigator.pop(context);
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: brandOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'About QuickGoals 🌟',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Version: v1.0.0',
              style: GoogleFonts.shareTechMono(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: brandOrange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'QuickGoals was developed by Nathan Dzamara, an aspiring software developer with a passion for helping students find balance in their lives. Designed with stress-free planning systems and delightful focus tools, it empowers you to organize, crush assignments, and work dynamically at your own pace.',
              style: GoogleFonts.quicksand(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Awesome!',
              style: TextStyle(color: brandOrange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _onBackPressed() {
    setState(() {
      _activeView = 'main';
    });
  }

  @override
  Widget build(BuildContext context) {
    String viewTitle = 'Settings';
    if (_activeView == 'account') viewTitle = 'Account Settings';
    if (_activeView == 'subjects') viewTitle = 'Subject Information';
    if (_activeView == 'pomodoro_settings') viewTitle = 'Pomodoro Settings';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 90.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unified Navigation Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_activeView != 'main')
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                          onPressed: _onBackPressed,
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QuickGoals',
                            style: GoogleFonts.quicksand(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            viewTitle,
                            style: GoogleFonts.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_activeView == 'main') _buildMainView(),
              if (_activeView == 'account') _buildAccountSettingsView(),
              if (_activeView == 'subjects') _buildSubjectsView(),
              if (_activeView == 'pomodoro_settings')
                _buildPomodoroSettingsView(),
            ],
          ),
        ),
      ),
    );
  }

  // --- FIGMA CARD 1: MAIN SETTINGS MENU ---
  Widget _buildMainView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFECECEC),
                child: Icon(Icons.person, color: Colors.grey, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: GoogleFonts.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edit Account details',
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                onPressed: () => setState(() => _activeView = 'account'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: () => setState(() => _activeView = 'subjects'),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 18.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subject Information',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 26),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                icon: Icons.access_time_rounded,
                title: 'Pomodoro Timer',
                onTap: () => setState(() => _activeView = 'pomodoro_settings'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildSettingsRow(
                icon: Icons.attach_file_rounded,
                title: 'Work Styles',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkstyleSettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildSettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'About',
                onTap: _showAboutAppDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- FIGMA CARD 2: DUAL-FORM TOGGLER ACCOUNT VIEW ---
  Widget _buildAccountSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMenuRowItem('Change account details', false, () {
                setState(() {
                  _activeAccountForm = 'details';
                });
              }),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildMenuRowItem('Log out of your account', false, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logging out of account safely...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildMenuRowItem('Moodle Account', false, () {
                setState(() {
                  _activeAccountForm = 'moodle';
                });
              }),
            ],
          ),
        ),

        // Dynamic subform card based on currently highlighted Figma wireframe toggle
        _activeAccountForm == 'details'
            ? Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _editNameController,
                      decoration: InputDecoration(
                        labelText: 'Change username...',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: brandOrange),
                        ),
                      ),
                      style: GoogleFonts.quicksand(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _editPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Change password...',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: brandOrange),
                        ),
                      ),
                      style: GoogleFonts.quicksand(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandOrange,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _userName = _editNameController.text.trim();
                          });
                          _saveSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account details saved!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          setState(() => _activeView = 'main');
                        },
                        child: Text(
                          'Save new details',
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link Moodle Portal',
                      style: GoogleFonts.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- DIRECT HANDSHAKE INSTRUCTIONS ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: brandOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connect Using Your Account:',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: brandOrange,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'To resolve token restrictions, please type your normal Wingu Academy portal Username and Password below.\n'
                            'The app will dynamically complete a secure handshake with the server to generate a perfect integration token automatically.',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[850],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _moodleIdentifierController,
                      decoration: InputDecoration(
                        labelText: 'Moodle Username',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: brandOrange),
                        ),
                      ),
                      style: GoogleFonts.quicksand(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _moodlePasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Moodle Password',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: brandOrange),
                        ),
                      ),
                      style: GoogleFonts.quicksand(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Automatic Task Insertion',
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Bypass review terminal stage gates',
                                style: GoogleFonts.quicksand(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAutoAddMode,
                          activeThumbColor: brandOrange,
                          onChanged: (val) =>
                              setState(() => _isAutoAddMode = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandOrange,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: _isAuthenticating
                            ? null
                            : _saveMoodleCredentials,
                        child: _isAuthenticating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Connect & Generate Token',
                                style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  // --- FIGMA CARD 3: SUBJECT CONFIGURATION DIRECTORY VIEW ---
  Widget _buildSubjectsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Configure Subject Paths ⚙️',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: brandOrange, size: 28),
              onPressed: _showAddSubjectDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: _subjects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No subjects added yet.',
                      style: GoogleFonts.quicksand(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subjects.length,
                  separatorBuilder: (context, idx) =>
                      Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final sub = _subjects[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: sub.subjectColor,
                        radius: 10,
                      ),
                      title: Text(
                        sub.name,
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _showSubjectDetailEditor(sub),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- FIGMA CARD 4: POMODORO SETTINGS SCREEN ---
  Widget _buildPomodoroSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sessions',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMenuRowItem('Focus', false, () {
                _showTimeSelectionDialog(
                  'Focus Session duration',
                  'focus_duration',
                  25,
                );
              }),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildMenuRowItem('Breaks', false, () {
                _showTimeSelectionDialog(
                  'Rest Break duration',
                  'break_duration',
                  5,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Productivity',
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMenuRowItem('Reward', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkstyleSettingsScreen(),
                  ),
                );
              }),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
                indent: 20,
                endIndent: 20,
              ),
              _buildMenuRowItem('Go to work style...', false, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkstyleSettingsScreen(),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showTimeSelectionDialog(
    String title,
    String key,
    int defaultMins,
  ) async {
    final storage = await SharedPreferences.getInstance();
    int activeMins = storage.getInt(key) ?? defaultMins;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$activeMins Minutes',
                style: GoogleFonts.shareTechMono(
                  fontSize: 22,
                  color: brandOrange,
                ),
              ),
              Slider(
                value: activeMins.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                activeColor: brandOrange,
                onChanged: (v) => setDialogState(() => activeMins = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await storage.setInt(key, activeMins);
                Navigator.pop(context);
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: brandOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRowItem(String title, bool padExtra, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: padExtra ? 18.0 : 14.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.grey[700]),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

// --- RESTORED: WORK STYLE OPTIONS SELECTOR ---
class WorkstyleSettingsScreen extends StatefulWidget {
  const WorkstyleSettingsScreen({super.key});

  @override
  State<WorkstyleSettingsScreen> createState() =>
      _WorkstyleSettingsScreenState();
}

class _WorkstyleSettingsScreenState extends State<WorkstyleSettingsScreen> {
  final Color brandOrange = const Color(0xFFFF8C42);
  final Color baseCanvasColor = const Color(0xFFF4F5F8);

  String _activeStrategy = 'Ice Cream';
  final List<TextEditingController> _rewardFieldsControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  @override
  void initState() {
    super.initState();
    _fetchPersistedSettings();
  }

  @override
  void dispose() {
    for (var ctrl in _rewardFieldsControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _fetchPersistedSettings() async {
    final storage = await SharedPreferences.getInstance();
    setState(() {
      _activeStrategy = storage.getString('currentWorkstyle') ?? 'Ice Cream';
      List<String> cachedRewards =
          storage.getStringList('pomodoroRewards') ??
          [
            'Stretch 🧘',
            'Grab a cold drink 🥤',
            'Play 1 song 🎵',
            'Check notification 📱',
            'Walk around 🚶',
          ];
      for (int i = 0; i < 5; i++) {
        if (i < cachedRewards.length) {
          _rewardFieldsControllers[i].text = cachedRewards[i];
        }
      }
    });
  }

  void _commitStrategyUpdate(String selectionValue) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setString('currentWorkstyle', selectionValue);
    setState(() {
      _activeStrategy = selectionValue;
    });
  }

  void _commitRewardsUpdate() async {
    final storage = await SharedPreferences.getInstance();
    List<String> outputList = _rewardFieldsControllers
        .map((c) => c.text.trim())
        .toList();
    await storage.setStringList('pomodoroRewards', outputList);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rewards rotation updated! 🎉',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
          ),
          backgroundColor: brandOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseCanvasColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Work Styles',
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can only pick 1 style',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _buildStrategySelectionCard(
              'Ice-cream',
              'Tasks are sorted from easiest to hardest or quickest to longest duration',
              'Ice Cream',
            ),
            const SizedBox(height: 12),
            _buildStrategySelectionCard(
              'Skyscraper',
              'Tasks are sorted from hardest to easiest tasks or longest duration to quickest duration. You build the foundation first.',
              'Skyscraper',
            ),
            const SizedBox(height: 12),
            _buildStrategySelectionCard(
              'Battleship',
              'Tasks are not sorted. You start a productivity session by playing a game of battleship where your subjects are scattered and hidden on a grid. Hitting a ship(ops, subject) starts a pomodoro session with that subjects tasks',
              'Battleship',
            ),
            const SizedBox(height: 32),
            Text(
              'Pomodoro Rewards (5 Step Rotation)',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildRewardsInputsPanel(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySelectionCard(
    String headline,
    String subtext,
    String modeKey,
  ) {
    final bool currentSelected = _activeStrategy == modeKey;

    return GestureDetector(
      onTap: () => _commitStrategyUpdate(modeKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  headline,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: currentSelected,
                  activeThumbColor: brandOrange,
                  onChanged: (val) {
                    if (val) _commitStrategyUpdate(modeKey);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtext,
              style: GoogleFonts.quicksand(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsInputsPanel() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          ...List.generate(5, (idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: TextField(
                controller: _rewardFieldsControllers[idx],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.wine_bar_rounded,
                    color: brandOrange,
                    size: 20,
                  ),
                  labelText: 'Interval Reward ${idx + 1}',
                  labelStyle: GoogleFonts.quicksand(color: Colors.grey),
                  floatingLabelStyle: GoogleFonts.quicksand(
                    color: brandOrange,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: baseCanvasColor.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey[100]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: brandOrange, width: 2),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _commitRewardsUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Save Custom Rewards',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
