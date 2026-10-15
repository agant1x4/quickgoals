import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task_models.dart';

class PomodoroPage extends StatefulWidget {
  final List<SubjectTaskData> userSubjects;
  final int initialSubjectIndex;

  const PomodoroPage({
    super.key,
    required this.userSubjects,
    this.initialSubjectIndex = 0,
  });

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  Timer? _countdownTimer;
  int _secondsRemaining = 25 * 60;
  bool _isPlaying = false;

  bool _isShowingBackSide = false;
  int _activeSubjectIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeSubjectIndex = widget.initialSubjectIndex;
    if (widget.userSubjects.isNotEmpty &&
        _activeSubjectIndex >= widget.userSubjects.length) {
      _activeSubjectIndex = 0;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _countdownTimer?.cancel();
        _isPlaying = false;
      } else {
        _isPlaying = true;
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              if (_secondsRemaining > 0) {
                _secondsRemaining--;
              } else {
                _countdownTimer?.cancel();
                _isPlaying = false;
              }
            });
          }
        });
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _countdownTimer?.cancel();
      _isPlaying = false;
      _secondsRemaining = 25 * 60;
    });
  }

  String _formattedTimerValue() {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _completeTask(SubjectTaskData? subject, TaskItem task) async {
    if (subject == null) return;
    setState(() {
      task.isCompleted = true;
      subject.registerTaskCompletion();
    });

    final storage = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      widget.userSubjects.map((s) => s.toMap()).toList(),
    );
    await storage.setString('quickgoals_user_subjects', encoded);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Fixed proportional diameter ensuring pristine layout on phone screens
    final double dialContainerSize = math.min(screenWidth * 0.72, 260.0);
    final double ringDiameter = dialContainerSize - 32;
    final double ringRadius = ringDiameter / 2.0;
    final double centerOffset = dialContainerSize / 2.0;

    const double slatePillWidth = 52.0;
    const double slatePillHeight = 22.0;
    const double orangePillWidth = 30.0;
    const double orangePillHeight = 12.0;

    final double slatePillPlacementRadius =
        ringRadius + 4.0 + (slatePillHeight / 2.0);
    final double slateX = centerOffset;
    final double slateY = centerOffset - slatePillPlacementRadius;

    const double orangeAngle = -math.pi / 2 - (math.pi / 6.5);
    final double orangePillPlacementRadius =
        ringRadius + 4.0 + (orangePillHeight / 2.0);
    final double orangeX =
        centerOffset + (orangePillPlacementRadius * math.cos(orangeAngle));
    final double orangeY =
        centerOffset + (orangePillPlacementRadius * math.sin(orangeAngle));

    final bool hasSubjects = widget.userSubjects.isNotEmpty;
    final SubjectTaskData? currentSubject = hasSubjects
        ? widget.userSubjects[_activeSubjectIndex]
        : null;

    final Color subjectThemeColor = currentSubject != null
        ? currentSubject.subjectColor
        : const Color(0xFFFFB75E);
    final String subjectThemeName = currentSubject != null
        ? currentSubject.name
        : 'General Study';

    final List<TaskItem> totalActiveTasks = currentSubject != null
        ? currentSubject.taskList.where((t) => !t.isCompleted).toList()
        : [];

    final lessons = totalActiveTasks.where((t) => t.type == 'Lesson').toList();
    final quizzes = totalActiveTasks.where((t) => t.type == 'Quiz').toList();
    final assignments = totalActiveTasks
        .where(
          (t) =>
              t.type == 'Assignment' || t.type == 'Project' || t.type == 'Exam',
        )
        .toList();

    int globalTaskCounter = 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E2841),
      // Removed endDrawer: AppMenuDrawer(...)
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QuickGoals',
                    style: GoogleFonts.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 2.0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pomodoro Timer',
                          style: GoogleFonts.quicksand(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity!.abs() > 200) {
                          setState(() {
                            _isShowingBackSide = !_isShowingBackSide;
                          });
                        }
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: _isShowingBackSide ? math.pi : 0,
                        ),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCubic,
                        builder: (context, angle, child) {
                          final bool isPastHalfway = angle >= (math.pi / 2);
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(angle),
                            child: isPastHalfway
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi),
                                    child: _buildBackSideView(
                                      dialContainerSize,
                                      ringDiameter,
                                      subjectThemeColor,
                                      subjectThemeName,
                                    ),
                                  )
                                : _buildFrontSideView(
                                    dialContainerSize,
                                    ringDiameter,
                                    slateX,
                                    slateY,
                                    slatePillWidth,
                                    slatePillHeight,
                                    orangeX,
                                    orangeY,
                                    orangePillWidth,
                                    orangePillHeight,
                                    orangeAngle,
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isShowingBackSide
                          ? "Tap core to switch subjects • Swipe back"
                          : "Swipe across timer to inspect core",
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectThemeName,
                              style: GoogleFonts.quicksand(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Activities to-do (Swipe right to complete)',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Height constraint set to 310 to accommodate floating bottom nav bar space
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 310),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32.0),
                  topRight: Radius.circular(32.0),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32.0),
                  topRight: Radius.circular(32.0),
                ),
                child: totalActiveTasks.isEmpty
                    ? Center(
                        child: Text(
                          '🎉 All clear! No pending activities.',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          24.0,
                          16.0,
                          24.0,
                          90.0,
                        ),
                        children: [
                          if (lessons.isNotEmpty) ...[
                            _buildSectionHeader('Lessons'),
                            ...lessons.map(
                              (task) => _buildTaskRow(
                                task,
                                globalTaskCounter++,
                                currentSubject,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (quizzes.isNotEmpty) ...[
                            _buildSectionHeader('Quiz'),
                            ...quizzes.map(
                              (task) => _buildTaskRow(
                                task,
                                globalTaskCounter++,
                                currentSubject,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (assignments.isNotEmpty) ...[
                            _buildSectionHeader('Assignments & Projects'),
                            ...assignments.map(
                              (task) => _buildTaskRow(
                                task,
                                globalTaskCounter++,
                                currentSubject,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey[200], thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTaskRow(TaskItem task, int index, SubjectTaskData? subject) {
    final bool isActive = index == 0;
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Dismissible(
          key: Key(task.id),
          direction: DismissDirection.startToEnd,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF53C580),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check, color: Colors.white),
          ),
          onDismissed: (_) {
            _completeTask(subject, task);
          },
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: isActive ? Colors.orange : const Color(0xFF91A3D1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${task.title} (${task.durationMinutes} mins)',
                  style: GoogleFonts.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontSideView(
    double containerSize,
    double ringDiameter,
    double slateX,
    double slateY,
    double slateW,
    double slateH,
    double orangeX,
    double orangeY,
    double orangeW,
    double orangeH,
    double orangeAngle,
  ) {
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: ringDiameter,
            height: ringDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC5D3ED).withValues(alpha: 0.85),
                width: 8,
              ),
            ),
            child: Center(
              child: Text(
                _formattedTimerValue(),
                style: GoogleFonts.quicksand(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ),
          Positioned(
            left: slateX - (slateW / 2.0),
            top: slateY - (slateH / 2.0),
            child: GestureDetector(
              onTap: _togglePlayPause,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: slateW,
                height: slateH,
                decoration: BoxDecoration(
                  color: const Color(0xFF5D7196),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: orangeX - (orangeW / 2.0),
            top: orangeY - (orangeH / 2.0),
            child: Transform.rotate(
              angle: orangeAngle + (math.pi / 2),
              child: GestureDetector(
                onTap: _resetTimer,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: orangeW,
                  height: orangeH,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB75E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackSideView(
    double containerSize,
    double ringDiameter,
    Color coreColor,
    String subjectName,
  ) {
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ringDiameter,
            height: ringDiameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2B3754),
            ),
          ),
          Container(
            width: ringDiameter,
            height: ringDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF38466B), width: 6),
            ),
          ),
          Positioned(
            top: ringDiameter * 0.14,
            child: Text(
              'Q',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.white12,
              ),
            ),
          ),
          Container(
            width: 154,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF141A29),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (widget.userSubjects.isNotEmpty) {
                setState(() {
                  _activeSubjectIndex =
                      (_activeSubjectIndex + 1) % widget.userSubjects.length;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 144,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: coreColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        bottomLeft: Radius.circular(9),
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.bolt, color: Colors.white, size: 16),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        subjectName.toUpperCase(),
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: ringDiameter * 0.14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "PRODUCT NO: QG-${(subjectName.hashCode % 9000 + 1000).abs()}",
                  style: GoogleFonts.spaceMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
