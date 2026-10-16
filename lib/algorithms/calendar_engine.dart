import '../models/task_models.dart';

class ScheduledTaskPosition {
  final TaskItem task;
  final SubjectTaskData subject;
  final double topOffset;
  final double height;
  final double leftIndent;
  final bool isFloating;

  ScheduledTaskPosition({
    required this.task,
    required this.subject,
    required this.topOffset,
    required this.height,
    this.leftIndent = 0.0,
    this.isFloating = false,
  });
}

class CalendarEngine {
  final int startHour; // 4 (4:00 AM)
  final int endHour; // 23 (11:00 PM)
  final double hourHeight; // 72.0 px per hour
  final double dailyCapacityCap; // 30.0 default soft cap

  CalendarEngine({
    this.startHour = 4,
    this.endHour = 23,
    this.hourHeight = 72.0,
    this.dailyCapacityCap = 30.0,
  });

  double get totalCanvasHeight => (endHour - startHour + 1) * hourHeight;

  double? getCurrentTimeOffset(DateTime? now) {
    if (now == null) return null;
    if (now.hour < startHour || now.hour > endHour) return null;
    final totalMinutesFromStart = ((now.hour - startHour) * 60) + now.minute;
    return (totalMinutesFromStart / 60.0) * hourHeight;
  }

  double getInitialScrollOffset(
    DateTime? now,
    List<ScheduledTaskPosition> scheduledTasks,
  ) {
    final liveOffset = getCurrentTimeOffset(now ?? DateTime.now());
    if (liveOffset != null) {
      return (liveOffset - 150.0).clamp(0.0, totalCanvasHeight);
    }
    if (scheduledTasks.isNotEmpty) {
      return (scheduledTasks.first.topOffset - 100.0).clamp(
        0.0,
        totalCanvasHeight,
      );
    }
    return 0.0;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _getNextWeekday(DateTime date) {
    DateTime next = date.add(const Duration(days: 1));
    while (next.weekday == DateTime.saturday ||
        next.weekday == DateTime.sunday) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Calculates effective load incorporating urgency multipliers based on deadline proximity
  double getEffectiveTaskLoad(TaskItem task) {
    double baseLoad = task.cognitiveLoad;
    final dueDate = task.dueDate;
    if (dueDate != null) {
      final difference = dueDate.difference(DateTime.now());
      final hoursUntilDue = difference.inHours;
      if (hoursUntilDue >= 0 && hoursUntilDue <= 24) {
        baseLoad *= 2.0; // Critical urgency boost (<= 24 hrs)
      } else if (hoursUntilDue > 24 && hoursUntilDue <= 48) {
        baseLoad *= 1.5; // Urgent boost (<= 48 hrs)
      } else if (hoursUntilDue > 48 && hoursUntilDue <= 72) {
        baseLoad *= 1.25; // Impending boost (<= 72 hrs)
      }
    }
    return baseLoad;
  }

  int _getSafeDurationMinutes(TaskItem task) {
    final raw = task.durationMinutes;
    return (raw > 0) ? raw : 30;
  }

  List<ScheduledTaskPosition> processTaskPositions(
    List<SubjectTaskData> subjects,
    DateTime targetDate,
  ) {
    List<ScheduledTaskPosition> positions = [];

    // 1. Collect all active tasks assigned to the target date, categorized by subject
    Map<SubjectTaskData, List<TaskItem>> subjectTasksMap = {};
    int totalTasksCount = 0;

    for (var subject in subjects) {
      final targetTasks = subject.taskList.where((task) {
        if (task.isCompleted || task.dueDate == null) return false;
        return _isSameDay(task.dueDate, targetDate);
      }).toList();

      if (targetTasks.isNotEmpty) {
        // Sort subject tasks by urgency / effective load
        targetTasks.sort((a, b) {
          final loadA = getEffectiveTaskLoad(a);
          final loadB = getEffectiveTaskLoad(b);
          return loadB.compareTo(loadA);
        });

        subjectTasksMap[subject] = targetTasks;
        totalTasksCount += targetTasks.length;
      }
    }

    if (totalTasksCount == 0) return [];

    // 2. Proportional slot allocation and interleave queuing across subjects
    List<Map<String, dynamic>> interleavedQueue = [];
    List<SubjectTaskData> activeSubjects = subjectTasksMap.keys.toList();

    // Weighted round-robin interleave giving proportional slots to busier subjects
    bool tasksRemaining = true;
    Map<SubjectTaskData, int> indices = {for (var s in activeSubjects) s: 0};

    while (tasksRemaining) {
      tasksRemaining = false;
      for (var subject in activeSubjects) {
        final list = subjectTasksMap[subject]!;
        final idx = indices[subject]!;
        if (idx < list.length) {
          interleavedQueue.add({'subject': subject, 'task': list[idx]});
          indices[subject] = idx + 1;
          tasksRemaining = true;
        }
      }
    }

    // 3. Layout allocation (8:00 AM - 6:00 PM primary range, 6:00 PM - 11:00 PM evening spillover)
    int primaryStartMinute = (8 - startHour) * 60; // 8:00 AM offset
    int primaryEndMinute = (18 - startHour) * 60; // 6:00 PM offset
    int currentMinute = primaryStartMinute;

    List<Map<String, dynamic>> overflowRolloverTasks = [];
    double accumulatedDailyLoad = 0.0;

    for (var item in interleavedQueue) {
      final task = item['task'] as TaskItem;
      final subject = item['subject'] as SubjectTaskData;
      final double effectiveLoad = getEffectiveTaskLoad(task);
      final int duration = _getSafeDurationMinutes(task);

      // Check daily capacity soft cap (30.0)
      if (accumulatedDailyLoad + effectiveLoad > dailyCapacityCap) {
        final lowerType = task.type.toLowerCase();
        final isRolloverEligible =
            lowerType.contains('lesson') ||
            lowerType.contains('read') ||
            lowerType.contains('quiz');

        // Only rollover lessons/readings/quizzes (NOT assignments or exams)
        if (isRolloverEligible) {
          overflowRolloverTasks.add(item);
          continue;
        }
      }

      accumulatedDailyLoad += effectiveLoad;

      if (currentMinute + duration <= primaryEndMinute) {
        // Fits within 8 AM - 6 PM primary window
        final top = (currentMinute / 60.0) * hourHeight;
        final height = (duration / 60.0) * hourHeight;

        positions.add(
          ScheduledTaskPosition(
            task: task,
            subject: subject,
            topOffset: top,
            height: height,
            isFloating: false,
          ),
        );

        currentMinute += duration + 15; // 15-minute padding between slots
      } else if (currentMinute + duration <= (endHour - startHour) * 60) {
        // Fits in late evening slot (6 PM - 11 PM) leaving room for class/breaks/sleep
        final top = (currentMinute / 60.0) * hourHeight;
        final height = (duration / 60.0) * hourHeight;

        positions.add(
          ScheduledTaskPosition(
            task: task,
            subject: subject,
            topOffset: top,
            height: height,
            leftIndent: 8.0,
            isFloating: true,
          ),
        );

        currentMinute += duration + 15;
      } else {
        // Exceeds canvas span
        final lowerType = task.type.toLowerCase();
        final isRolloverEligible =
            lowerType.contains('lesson') ||
            lowerType.contains('read') ||
            lowerType.contains('quiz');

        if (isRolloverEligible) {
          overflowRolloverTasks.add(item);
        } else {
          // Force place strict deadlines (Assignments/Exams) at the end of the canvas
          final top = ((endHour - startHour - 1) * hourHeight);
          positions.add(
            ScheduledTaskPosition(
              task: task,
              subject: subject,
              topOffset: top,
              height: (duration / 60.0) * hourHeight,
              leftIndent: 16.0,
              isFloating: true,
            ),
          );
        }
      }
    }

    // 4. Move overflow rollover tasks to the next weekday
    if (overflowRolloverTasks.isNotEmpty) {
      final nextWeekday = _getNextWeekday(targetDate);
      for (var overflow in overflowRolloverTasks) {
        final task = overflow['task'] as TaskItem;
        final existingHour = task.dueDate?.hour ?? 23;
        final existingMinute = task.dueDate?.minute ?? 59;

        task.dueDate = DateTime(
          nextWeekday.year,
          nextWeekday.month,
          nextWeekday.day,
          existingHour,
          existingMinute,
        );
      }
    }

    return positions;
  }
}
