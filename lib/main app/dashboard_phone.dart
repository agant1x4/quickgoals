import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_models.dart';
import '../widgets/geometry.dart';
import '../widgets/task_config_sheet.dart';
import '../algorithms/sorting_engine.dart';
import 'pomodoro.dart';
import 'nav_drawer.dart'; // Imports FloatingNavBar

void main() {
  runApp(const QuickGoalsApp());
}

class QuickGoalsApp extends StatelessWidget {
  const QuickGoalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickGoals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.quicksandTextTheme(),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLockedIn = false;
  String _currentStrategy = 'Ice Cream';
  List<SubjectTaskData> _userSubjects = [];
  SubjectTaskData? _selectedSidePanelSubject;
  int _currentNavIndex = 0; // Active nav bar index

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  void _loadAppState() async {
    final storage = await SharedPreferences.getInstance();
    final String? strategy = storage.getString('currentWorkstyle');
    final String? subjectsJson = storage.getString('quickgoals_user_subjects');

    if (mounted) {
      setState(() {
        _currentStrategy = strategy ?? 'Ice Cream';
        if (subjectsJson != null && subjectsJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(subjectsJson);
            _userSubjects = decoded.map((item) {
              if (item is Map<String, dynamic>) {
                return SubjectTaskData.fromMap(item);
              }
              return SubjectTaskData(
                name: item.toString(),
                subjectColor: const Color(0xFFFFB75E),
              );
            }).toList();
          } catch (e) {
            _userSubjects = [];
            storage.remove('quickgoals_user_subjects');
          }
        } else {
          _userSubjects = [];
        }
      });
    }
  }

  void _saveAppState() async {
    final storage = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _userSubjects.map((s) => s.toMap()).toList(),
    );
    await storage.setString('quickgoals_user_subjects', encoded);
  }

  void _openSidePanel(SubjectTaskData subject) {
    setState(() {
      _selectedSidePanelSubject = subject;
    });
  }

  void _closeSidePanel() {
    setState(() {
      _selectedSidePanelSubject = null;
    });
  }

  void _completeTask(SubjectTaskData subject, TaskItem task) {
    setState(() {
      task.isCompleted = true;
      subject.registerTaskCompletion();
    });
    _saveAppState();
  }

  int _calculateTasksCompletedToday() {
    int total = 0;
    for (var subject in _userSubjects) {
      for (var task in subject.taskList) {
        if (task.isCompleted) {
          total++;
        }
      }
    }
    return total;
  }

  int _calculateTotalPomodoroMins() {
    int totalMins = 0;
    for (var subject in _userSubjects) {
      for (var task in subject.taskList) {
        if (task.isCompleted) {
          totalMins += task.durationMinutes;
        }
      }
    }
    return totalMins > 0 ? totalMins : 45;
  }

  @override
  Widget build(BuildContext context) {
    SortingEngine.sortSubjects(_userSubjects, _currentStrategy);

    final bool isAllCaughtUp =
        _userSubjects.isEmpty ||
        _userSubjects.every((s) => s.totalOverdueTasks == 0);

    final mostOverdueSubject = _userSubjects.firstWhere(
      (s) => s.totalOverdueTasks > 0,
      orElse: () => _userSubjects.isNotEmpty
          ? _userSubjects.first
          : SubjectTaskData(
              name: 'No Tasks',
              subjectColor: const Color(0xFFFFB75E),
            ),
    );

    final secondarySubjects = _userSubjects
        .where((s) => s != mostOverdueSubject && s.totalOverdueTasks > 0)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Enables glass blur underneath floating bar
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: 110.0, // Ensures content clears the bottom nav bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER VIEW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _openTaskConfigurationModal(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB75E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
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
                    ],
                  ),
                  const SizedBox(height: 20),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutBack,
                    child: FractionallySizedBox(
                      key: ValueKey(
                        isAllCaughtUp
                            ? 'caught_up_view'
                            : mostOverdueSubject.name,
                      ),
                      widthFactor: 0.95,
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          if (!isAllCaughtUp) {
                            _openSidePanel(mostOverdueSubject);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: ShapeDecoration(
                            color: isAllCaughtUp
                                ? const Color(0xFFFFB75E)
                                : mostOverdueSubject.subjectColor,
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            shape: const FigmaSmoothRectBorder(
                              radius: 30.0,
                              smoothing: 0.60,
                            ),
                          ),
                          child: isAllCaughtUp
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'All caught up! 🎉',
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _openTaskConfigurationModal(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 10,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.25,
                                          ),
                                          shape: StadiumBorder(
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.50,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Add a new activity',
                                          style: GoogleFonts.quicksand(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              mostOverdueSubject.name,
                                              style: GoogleFonts.quicksand(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.32,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                '${mostOverdueSubject.totalOverdueTasks} due',
                                                style: GoogleFonts.quicksand(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (mostOverdueSubject.currentStreak >
                                            0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '🔥 ${mostOverdueSubject.currentStreak}d Streak',
                                              style: GoogleFonts.quicksand(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '• ${mostOverdueSubject.taskList.where((t) => !t.isCompleted && t.type == 'Lesson').length} Lessons Remaining',
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• ${mostOverdueSubject.taskList.where((t) => !t.isCompleted && t.type == 'Quiz').length} Quizzes Remaining',
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• ${mostOverdueSubject.taskList.where((t) => !t.isCompleted && t.type == 'Assignment').length} Assignments Remaining',
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isLockedIn = !_isLockedIn;
                                        });
                                        final int initialIndex = _userSubjects
                                            .indexOf(mostOverdueSubject);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PomodoroPage(
                                              userSubjects: _userSubjects,
                                              initialSubjectIndex:
                                                  initialIndex >= 0
                                                  ? initialIndex
                                                  : 0,
                                            ),
                                          ),
                                        ).then((_) => _loadAppState());
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: _isLockedIn
                                              ? const Color(0xFF53C580)
                                              : const Color(0xFF1E2841),
                                          shape: StadiumBorder(
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.40,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _isLockedIn
                                              ? 'Active Focus Session'
                                              : 'Lock-In Now ⏱️',
                                          style: GoogleFonts.quicksand(
                                            color: Colors.white,
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
                  ),

                  const SizedBox(height: 24),
                  Container(height: 1, color: const Color(0xFFECECEC)),
                  const SizedBox(height: 22),

                  Text(
                    'Keep an eye on these',
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 14),

                  (isAllCaughtUp || secondarySubjects.isEmpty)
                      ? Padding(
                          padding: const EdgeInsets.only(
                            bottom: 14.0,
                            top: 4.0,
                          ),
                          child: Text(
                            'All caught up! You\'ve got everything in the bag.',
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF777777),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: secondarySubjects.length,
                          itemBuilder: (context, index) {
                            final item = secondarySubjects[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GestureDetector(
                                onTap: () => _openSidePanel(item),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: CustomPaint(
                                        size: const Size(12, 12),
                                        painter: SmoothPentagonPainter(
                                          color: item.subjectColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${item.name}: ${item.totalOverdueTasks} activities need work',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF444444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 24),
                  Container(height: 1, color: const Color(0xFFECECEC)),
                  const SizedBox(height: 22),

                  Text(
                    'You absolutely ate this week up, no crumbs. ✨',
                    style: GoogleFonts.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // GREEN & BLUE STATS ROW
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: const ShapeDecoration(
                            color: Color(0xFF81C37F),
                            shape: FigmaSmoothRectBorder(
                              radius: 28,
                              smoothing: 0.60,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Icon(
                                    Icons.task_alt,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_calculateTasksCompletedToday()}',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Tasks Completed Today',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: const ShapeDecoration(
                            color: Color(0xFF91A3D1),
                            shape: FigmaSmoothRectBorder(
                              radius: 28,
                              smoothing: 0.60,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  Icon(
                                    Icons.bolt,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_calculateTotalPomodoroMins()}m',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Pomodoro Focus Time',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // BROWN CARD
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(18),
                    decoration: const ShapeDecoration(
                      color: Color(0xFFB88362),
                      shape: FigmaSmoothRectBorder(radius: 28, smoothing: 0.60),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Weekly Activity Overview',
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'This Week',
                              style: GoogleFonts.quicksand(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBarChartColumn('M', 0.4),
                            _buildBarChartColumn('T', 0.6),
                            _buildBarChartColumn('W', 0.3),
                            _buildBarChartColumn('T', 0.8),
                            _buildBarChartColumn('F', 0.9),
                            _buildBarChartColumn('S', 0.5),
                            _buildBarChartColumn('S', 0.7),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            if (_selectedSidePanelSubject != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSidePanel,
                  child: Container(color: Colors.black26),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _selectedSidePanelSubject != null ? 0 : -320,
              width: 320,
              child: Material(
                elevation: 16,
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedSidePanelSubject?.name ?? '',
                                style: GoogleFonts.quicksand(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _closeSidePanel,
                            ),
                          ],
                        ),
                        if (_selectedSidePanelSubject != null)
                          Text(
                            'Streak: 🔥 ${_selectedSidePanelSubject!.currentStreak} days',
                            style: GoogleFonts.quicksand(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const Divider(height: 24),
                        Text(
                          'Pending Tasks (Swipe to complete)',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              _selectedSidePanelSubject == null ||
                                  _selectedSidePanelSubject!.taskList
                                      .where((t) => !t.isCompleted)
                                      .isEmpty
                              ? Center(
                                  child: Text(
                                    'No pending tasks!',
                                    style: GoogleFonts.quicksand(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView(
                                  children: _selectedSidePanelSubject!.taskList
                                      .where((t) => !t.isCompleted)
                                      .map((task) {
                                        return Dismissible(
                                          key: Key(task.id),
                                          direction:
                                              DismissDirection.endToStart,
                                          onDismissed: (_) {
                                            _completeTask(
                                              _selectedSidePanelSubject!,
                                              task,
                                            );
                                          },
                                          background: Container(
                                            color: const Color(0xFF53C580),
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(
                                              right: 20,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              task.title,
                                              style: GoogleFonts.quicksand(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${task.type} • ${task.durationMinutes} mins',
                                              style: GoogleFonts.quicksand(
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                color: Color(0xFF53C580),
                                              ),
                                              onPressed: () {
                                                _completeTask(
                                                  _selectedSidePanelSubject!,
                                                  task,
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
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
      ),
    );
  }

  Widget _buildBarChartColumn(String dayLabel, double heightFactor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 60 * heightFactor,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayLabel,
          style: GoogleFonts.quicksand(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _openTaskConfigurationModal(BuildContext context) {
    if (_userSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No subjects configured! Please run the onboarding flow to set up subjects.",
          ),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
      ),
      builder: (context) {
        return TaskConfigSheet(
          userSubjects: _userSubjects,
          onTaskCreated: (subject, task) {
            setState(() {
              task.subjectName = subject.name;
              subject.taskList.add(task);
            });
            _saveAppState();
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
