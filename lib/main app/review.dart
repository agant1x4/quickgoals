import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_models.dart';
import '../services/moodle_service.dart';
import '../algorithms/calendar_engine.dart';
import '../widgets/geometry.dart';
import '../widgets/task_pill_card.dart';
import 'nav_drawer.dart';
import 'pomodoro.dart';

class ReviewPage extends StatefulWidget {
  final List<SubjectTaskData> userSubjects;

  const ReviewPage({super.key, this.userSubjects = const []});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

enum CalendarViewScope { day, week, month }

class _ReviewPageState extends State<ReviewPage> {
  final CalendarEngine _calendarEngine = CalendarEngine(
    startHour: 4,
    endHour: 23,
    hourHeight: 72.0,
  );
  late final ScrollController _timelineScrollController;

  int _currentNavIndex = 3; // Defaults to index 3 (Calendar/Schedule)
  bool _isLoading = true;
  CalendarViewScope _currentView = CalendarViewScope.day;
  DateTime _selectedDate = DateTime.now();
  double _dailySoftCap = 30.0;

  List<SubjectTaskData> _activeSubjects = [];
  _CalendarTaskWrapper? _selectedTask;

  bool _isMultiSelectMode = false;
  final Set<_CalendarTaskWrapper> _selectedTasks = {};

  final Color _dayColor = const Color(0xFFFFB03B);
  final Color _weekColor = const Color(0xFF6C9EFF);
  final Color _monthColor = const Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _activeSubjects = List.from(widget.userSubjects);
    _timelineScrollController = ScrollController();
    _initializeCalendarAndSync();
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  double _calculateTotalLoadForDate(DateTime date) {
    double total = 0.0;
    for (var subject in _activeSubjects) {
      for (var task in subject.taskList) {
        if (!task.isCompleted &&
            task.dueDate != null &&
            _isSameDay(task.dueDate!, date)) {
          total += _calendarEngine.getEffectiveTaskLoad(task);
        }
      }
    }
    return total;
  }

  void _checkSoftCapWarning(DateTime date) {
    final currentLoad = _calculateTotalLoadForDate(date);
    if (currentLoad > _dailySoftCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Daily workload capacity warning (${currentLoad.toStringAsFixed(1)} / ${_dailySoftCap.toInt()} Load). Consider spreading out tasks.",
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFE53935),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _initializeCalendarAndSync() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('moodle_token');

    if (_activeSubjects.isEmpty) {
      final cachedJson = prefs.getString('quickgoals_user_subjects');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedJson);
          _activeSubjects = decoded
              .map((e) => SubjectTaskData.fromMap(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint("Failed to decode subject cache: $e");
        }
      }
    }

    if (_activeSubjects.isEmpty) {
      _activeSubjects = [
        SubjectTaskData(
          name: "General",
          subjectColor: const Color(0xFFFFB03B),
          taskList: [],
        ),
      ];
    }

    if (savedToken != null && savedToken.trim().isNotEmpty) {
      try {
        final moodleService = MoodleService(token: savedToken.trim());
        final rawActivities = await moodleService.fetchMoodleActivities();
        _activeSubjects = moodleService.mapMoodleActivitiesToSubjects(
          rawActivities: rawActivities,
          userSubjects: _activeSubjects,
        );
        await _saveSubjectsCache();
      } catch (e) {
        debugPrint("Moodle direct sync error: $e");
      }
    }

    final positions = _calendarEngine.processTaskPositions(
      _activeSubjects,
      _selectedDate,
    );
    if (positions.isNotEmpty) {
      _selectedTask = _CalendarTaskWrapper(
        subject: positions.first.subject,
        task: positions.first.task,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_timelineScrollController.hasClients) {
          final initialOffset = _calendarEngine.getInitialScrollOffset(
            DateTime.now(),
            positions,
          );
          _timelineScrollController.jumpTo(initialOffset);
        }
        _checkSoftCapWarning(_selectedDate);
      });
    }
  }

  Future<void> _saveSubjectsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _activeSubjects.map((s) => s.toMap()).toList();
    await prefs.setString('quickgoals_user_subjects', jsonEncode(jsonList));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return "$minutes mins";
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) return "$hours hr${hours > 1 ? 's' : ''}";
    return "$hours hr $remainingMins mins";
  }

  void _toggleTaskSelection(_CalendarTaskWrapper item) {
    setState(() {
      if (_selectedTasks.contains(item)) {
        _selectedTasks.remove(item);
        if (_selectedTasks.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedTasks.add(item);
      }
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedTasks.clear();
    });
  }

  void _completeTaskFromReview(_CalendarTaskWrapper wrapper) {
    setState(() {
      wrapper.task.isCompleted = true;
      wrapper.subject.taskList.remove(wrapper.task);
    });
    _saveSubjectsCache();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Completed: ${wrapper.task.title}"),
        backgroundColor: const Color(0xFF53C580),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditTaskModal(_CalendarTaskWrapper wrapper) {
    final titleController = TextEditingController(text: wrapper.task.title);
    final descController = TextEditingController(
      text: wrapper.task.description,
    );
    int selectedDuration = wrapper.task.durationMinutes;
    DateTime newDueDate = wrapper.task.dueDate ?? _selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              title: Text(
                "Edit Activity",
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: "Activity Title",
                        labelStyle: GoogleFonts.quicksand(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Description",
                        labelStyle: GoogleFonts.quicksand(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          "Duration:",
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<int>(
                          value:
                              [
                                15,
                                30,
                                45,
                                60,
                                90,
                                120,
                              ].contains(selectedDuration)
                              ? selectedDuration
                              : 30,
                          items: [15, 30, 45, 60, 90, 120].map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(_formatDuration(m)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setModalState(() => selectedDuration = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.quicksand(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB03B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      wrapper.task.title = titleController.text.trim();
                      wrapper.task.description = descController.text.trim();
                      wrapper.task.durationMinutes = selectedDuration;
                      wrapper.task.dueDate = newDueDate;
                    });
                    _saveSubjectsCache();
                    Navigator.pop(context);
                    _checkSoftCapWarning(newDueDate);
                  },
                  child: Text(
                    "Save",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuickgoalBundleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        int totalMins = _selectedTasks.fold(
          0,
          (sum, item) => sum + item.task.durationMinutes,
        );
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Quickgoal Bundle',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bundling ${_selectedTasks.length} tasks ($totalMins mins total duration)',
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _exitMultiSelectMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quickgoal bundle created successfully!'),
                        backgroundColor: Color(0xFF53C580),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Confirm Bundle',
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTaskDetailDrawer(_CalendarTaskWrapper wrapper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTaskDetailContent(wrapper, isModal: true),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        onAddPressed: () {
          // Add task action
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB03B)),
              )
            : Stack(
                children: [
                  isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
                  if (_isMultiSelectMode)
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E293B,
                          ).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _exitMultiSelectMode,
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedTasks.length} selected',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _selectedTasks.isEmpty
                                  ? null
                                  : _showQuickgoalBundleSheet,
                              icon: const Icon(
                                Icons.bolt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Bundle Quickgoal',
                                style: GoogleFonts.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB03B),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderBar(),
        _buildViewSwitcher(),
        _buildDateHeader(),
        Expanded(child: _buildTimelineCanvasView()),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildViewSwitcher(),
                    _buildDateHeader(),
                    Expanded(child: _buildTimelineCanvasView()),
                  ],
                ),
              ),
              Container(width: 1, color: const Color(0xFFEFEFEF)),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: _selectedTask != null
                      ? _buildTaskDetailContent(_selectedTask!)
                      : Center(
                          child: Text(
                            "Select an activity to view details",
                            style: GoogleFonts.quicksand(color: Colors.grey),
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

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        "Calendar",
        style: GoogleFonts.quicksand(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          _buildScopeChip("Day", CalendarViewScope.day, _dayColor),
          const SizedBox(width: 10),
          _buildScopeChip("Week", CalendarViewScope.week, _weekColor),
          const SizedBox(width: 10),
          _buildScopeChip("Month", CalendarViewScope.month, _monthColor),
        ],
      ),
    );
  }

  Widget _buildScopeChip(
    String label,
    CalendarViewScope scope,
    Color activeColor,
  ) {
    final bool isActive = _currentView == scope;
    return GestureDetector(
      onTap: () => setState(() => _currentView = scope),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: ShapeDecoration(
          color: isActive ? activeColor : const Color(0xFFE0E0E0),
          shape: const FigmaSmoothRectBorder(radius: 20, smoothing: 0.60),
        ),
        child: Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : const Color(0xFF616161),
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    String dayName = days[_selectedDate.weekday - 1];
    String monthName = months[_selectedDate.month - 1];
    String dateText = "$dayName  $monthName ${_selectedDate.day}";
    final double totalLoad = _calculateTotalLoadForDate(_selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateText,
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Workload: ${totalLoad.toStringAsFixed(1)} / ${_dailySoftCap.toInt()} Load",
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: totalLoad > _dailySoftCap
                      ? const Color(0xFFE53935)
                      : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: const Color(0xFF64748B),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _checkSoftCapWarning(_selectedDate);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: const Color(0xFFFFB03B),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _checkSoftCapWarning(_selectedDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCanvasView() {
    final scheduledPositions = _calendarEngine.processTaskPositions(
      _activeSubjects,
      _selectedDate,
    );
    final now = DateTime.now();
    final bool isToday = _isSameDay(_selectedDate, now);

    final int startHour = _calendarEngine.startHour;
    final int endHour = _calendarEngine.endHour;
    final double hourHeight = _calendarEngine.hourHeight;
    final int totalHours = endHour - startHour + 1;

    final double liveOffset = _calendarEngine.getCurrentTimeOffset(now) ?? -1.0;

    return SingleChildScrollView(
      controller: _timelineScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 140),
      child: SizedBox(
        height: _calendarEngine.totalCanvasHeight,
        child: Stack(
          children: [
            Column(
              children: List.generate(totalHours, (index) {
                final hour = startHour + index;
                final hourText = "${hour.toString().padLeft(2, '0')}:00";

                return SizedBox(
                  height: hourHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(
                            hourText,
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (isToday && liveOffset >= 0) ...[
              Positioned(
                top: liveOffset,
                left: 48,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...scheduledPositions.map((position) {
              final task = position.task;
              final subject = position.subject;
              final wrapper = _CalendarTaskWrapper(
                subject: subject,
                task: task,
              );

              final double leftPosition = 68.0 + position.leftIndent;
              const double pillWidth = 220.0;
              final bool isSelected = _selectedTasks.contains(wrapper);

              return Positioned(
                top: position.topOffset,
                left: leftPosition,
                child: TaskPillCard(
                  title: task.title,
                  durationMinutes: task.durationMinutes,
                  subjectColor: subject.subjectColor,
                  width: pillWidth,
                  height: position.height,
                  isSelected: isSelected,
                  isMultiSelectMode: _isMultiSelectMode,
                  onTap: () {
                    if (_isMultiSelectMode) {
                      _toggleTaskSelection(wrapper);
                    } else {
                      setState(() => _selectedTask = wrapper);
                      if (MediaQuery.of(context).size.width < 700) {
                        _showTaskDetailDrawer(wrapper);
                      }
                    }
                  },
                  onLongPress: () {
                    if (!_isMultiSelectMode) {
                      setState(() {
                        _isMultiSelectMode = true;
                        _selectedTasks.add(wrapper);
                      });
                    }
                  },
                  onDismissed: (_) => _completeTaskFromReview(wrapper),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskDetailContent(
    _CalendarTaskWrapper wrapper, {
    bool isModal = false,
  }) {
    final task = wrapper.task;
    final subject = wrapper.subject;

    final String dueFormatted = task.dueDate != null
        ? "${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}/${task.dueDate!.year}"
        : "No Deadline";

    final String startTimeFormatted = task.dueDate != null
        ? "${task.dueDate!.hour.toString().padLeft(2, '0')}:${task.dueDate!.minute.toString().padLeft(2, '0')}"
        : "08:00";

    final String deadlineFormatted = task.dueDate != null
        ? "${task.dueDate!.add(Duration(minutes: task.durationMinutes)).hour.toString().padLeft(2, '0')}:${task.dueDate!.add(Duration(minutes: task.durationMinutes)).minute.toString().padLeft(2, '0')}"
        : "08:30";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
                onPressed: () => _showEditTaskModal(wrapper),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: ShapeDecoration(
              color: subject.subjectColor,
              shape: const FigmaSmoothRectBorder(radius: 12, smoothing: 0.60),
            ),
            child: Text(
              subject.name,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            task.description.isNotEmpty
                ? task.description
                : "concise description of activity",
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildDetailRow("Duration:", _formatDuration(task.durationMinutes)),
          const SizedBox(height: 10),
          _buildDetailRow("Start Time:", startTimeFormatted),
          const SizedBox(height: 20),
          _buildDetailRow("Due date:", dueFormatted),
          const SizedBox(height: 10),
          _buildDetailRow("Deadline:", deadlineFormatted),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                if (isModal) Navigator.pop(context);
                int sIndex = _activeSubjects.indexOf(subject);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PomodoroPage(
                      userSubjects: _activeSubjects,
                      initialSubjectIndex: sIndex < 0 ? 0 : sIndex,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                "Start Focus Session",
                style: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB03B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _CalendarTaskWrapper {
  final SubjectTaskData subject;
  final TaskItem task;

  _CalendarTaskWrapper({required this.subject, required this.task});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CalendarTaskWrapper &&
          runtimeType == other.runtimeType &&
          task.id == other.task.id &&
          subject.name == other.subject.name;

  @override
  int get hashCode => task.id.hashCode ^ subject.name.hashCode;
}
