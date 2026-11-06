import 'package:flutter/material.dart';
import 'task_load.dart';

// --- TASK ITEM DATA MODEL ---
class TaskItem {
  final String id;
  String title;
  String type; // 'Lesson', 'Quiz', 'Assignment', 'Exam'
  String description;
  int difficulty; // 1 to 5
  TaskLoad load;
  DateTime? dueDate;
  bool isCompleted;
  int durationMinutes;
  String? subjectName;
  bool isExam;
  String? customName;

  TaskItem({
    required this.id,
    required this.title,
    required this.type,
    this.description = '',
    this.difficulty = 3,
    this.load = TaskLoad.good,
    this.dueDate,
    this.isCompleted = false,
    this.durationMinutes = 30,
    this.subjectName,
    this.isExam = false,
    this.customName,
  });

  /// Single Task Cognitive Load (for Burnout Soft Cap)
  double get cognitiveLoad => difficulty * load.multiplier;

  /// Task Weight (for Daily Streak Calculation)
  double get streakWeight => difficulty + (load.multiplier * 2.0);

  /// Display title giving precedence to optional custom alias
  String get displayTitle =>
      (customName != null && customName!.trim().isNotEmpty)
          ? customName!
          : title;

  TaskItem copyWith({
    String? id,
    String? title,
    String? type,
    String? description,
    int? difficulty,
    TaskLoad? load,
    DateTime? dueDate,
    bool? isCompleted,
    int? durationMinutes,
    String? subjectName,
    bool? isExam,
    String? customName,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      load: load ?? this.load,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      subjectName: subjectName ?? this.subjectName,
      isExam: isExam ?? this.isExam,
      customName: customName ?? this.customName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'description': description,
      'difficulty': difficulty,
      'load': load.name,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'durationMinutes': durationMinutes,
      'subjectName': subjectName,
      'isExam': isExam,
      'customName': customName,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] ?? '',
      type: map['type'] ?? 'Lesson',
      description: map['description'] ?? '',
      difficulty: map['difficulty'] ?? 3,
      load: TaskLoad.values.firstWhere(
        (e) => e.name == map['load'],
        orElse: () => TaskLoad.good,
      ),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      isCompleted: map['isCompleted'] ?? false,
      durationMinutes: map['durationMinutes'] ?? 30,
      subjectName: map['subjectName'],
      isExam: map['isExam'] ?? false,
      customName: map['customName'],
    );
  }
}

// --- SUBJECT TASK DATA MODEL ---
class SubjectTaskData {
  final String name;
  final Color subjectColor;
  String? customName; // Optional user-facing rename / alias
  DateTime? examDate; // Critical exam / target deadline
  String? preferredStudyWindow; // e.g. 'Morning', 'Afternoon', 'Evening'

  int lessonDifficulty;
  int quizDifficulty;
  int assignmentDifficulty;

  int motivationLevel;
  int averageDurationMins;

  // Streak tracking fields
  int currentStreak;
  int bestStreak;
  DateTime? lastCompletedDate;

  List<TaskItem> taskList;

  SubjectTaskData({
    required this.name,
    required this.subjectColor,
    this.customName,
    this.examDate,
    this.preferredStudyWindow,
    this.lessonDifficulty = 3,
    this.quizDifficulty = 3,
    this.assignmentDifficulty = 3,
    this.motivationLevel = 3,
    this.averageDurationMins = 30,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    List<TaskItem>? taskList,
  }) : taskList = taskList ?? [];

  /// User-friendly display name falling back to system/Moodle course name
  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty)
          ? customName!
          : name;

  void registerTaskCompletion() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastCompletedDate == null) {
      currentStreak = 1;
    } else {
      final lastDate = DateTime(
        lastCompletedDate!.year,
        lastCompletedDate!.month,
        lastCompletedDate!.day,
      );
      final difference = today.difference(lastDate).inDays;

      if (difference == 1) {
        currentStreak += 1;
      } else if (difference > 1) {
        currentStreak = 1;
      }
    }

    lastCompletedDate = now;
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }
  }

  int get totalOverdueTasks {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return taskList
        .where(
          (t) =>
              !t.isCompleted &&
              t.dueDate != null &&
              t.dueDate!.isBefore(startOfToday),
        )
        .length;
  }

  int get overdueAge {
    final now = DateTime.now();
    int maxDays = 0;
    for (var task in taskList) {
      if (!task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isBefore(now)) {
        final difference = now.difference(task.dueDate!).inDays;
        if (difference > maxDays) {
          maxDays = difference;
        }
      }
    }
    return maxDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subjectColor': subjectColor.toARGB32(),
      'customName': customName,
      'examDate': examDate?.toIso8601String(),
      'preferredStudyWindow': preferredStudyWindow,
      'lessonDifficulty': lessonDifficulty,
      'quizDifficulty': quizDifficulty,
      'assignmentDifficulty': assignmentDifficulty,
      'motivationLevel': motivationLevel,
      'averageDurationMins': averageDurationMins,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'taskList': taskList.map((t) => t.toMap()).toList(),
    };
  }

  factory SubjectTaskData.fromMap(Map<String, dynamic> map) {
    return SubjectTaskData(
      name: map['name'] ?? '',
      subjectColor: Color(map['subjectColor'] ?? 0xFFFFB75E),
      customName: map['customName'],
      examDate: map['examDate'] != null ? DateTime.tryParse(map['examDate']) : null,
      preferredStudyWindow: map['preferredStudyWindow'],
      lessonDifficulty: map['lessonDifficulty'] ?? 3,
      quizDifficulty: map['quizDifficulty'] ?? 3,
      assignmentDifficulty: map['assignmentDifficulty'] ?? 3,
      motivationLevel: map['motivationLevel'] ?? 3,
      averageDurationMins: map['averageDurationMins'] ?? 30,
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      lastCompletedDate: map['lastCompletedDate'] != null
          ? DateTime.tryParse(map['lastCompletedDate'])
          : null,
      taskList: map['taskList'] != null
          ? List<TaskItem>.from(
              (map['taskList'] as List).map((t) => TaskItem.fromMap(t)),
            )
          : [],
    );
  }
}

// --- PRODUCTIVITY PROFILE DATA MODEL ---
class ProductivityProfile {
  final List<String> studyWindows;
  final List<String> bestDays;
  final String strategy;
  final double dailyCapacityCap;
  final String? studentArchetype;

  const ProductivityProfile({
    this.studyWindows = const ['Morning'],
    this.bestDays = const ['Monday', 'Wednesday', 'Friday'],
    this.strategy = 'Ice Cream',
    this.dailyCapacityCap = 30.0,
    this.studentArchetype,
  });

  Map<String, dynamic> toMap() {
    return {
      'studyWindows': studyWindows,
      'bestDays': bestDays,
      'strategy': strategy,
      'dailyCapacityCap': dailyCapacityCap,
      'studentArchetype': studentArchetype,
    };
  }

  factory ProductivityProfile.fromMap(Map<String, dynamic> map) {
    return ProductivityProfile(
      studyWindows: map['studyWindows'] != null
          ? List<String>.from(map['studyWindows'])
          : const ['Morning'],
      bestDays: map['bestDays'] != null
          ? List<String>.from(map['bestDays'])
          : const ['Monday', 'Wednesday', 'Friday'],
      strategy: map['strategy'] ?? 'Ice Cream',
      dailyCapacityCap: (map['dailyCapacityCap'] as num?)?.toDouble() ?? 30.0,
      studentArchetype: map['studentArchetype'],
    );
  }
}
