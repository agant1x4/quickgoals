import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_models.dart';
import '../models/task_load.dart';

/// Comprehensive service for interacting with Moodle Web Services API.
/// Handles authentication, module extraction (lessons, quizzes, assignments),
/// completion filtering, Levenshtein fuzzy course matching, and hourly sync tracking.
class MoodleService {
  final String baseUrl;
  final String token;

  static const String _lastSyncKey = 'moodle_last_sync_timestamp';

  MoodleService({
    required this.token,
    this.baseUrl = 'https://www.winguacademy.co.za',
  });

  /// Authenticates with Moodle via username/password and retrieves a Web Service token.
  static Future<String?> authenticateAndFetchToken({
    required String username,
    required String password,
    String portalUrl = 'https://www.winguacademy.co.za',
  }) async {
    final formattedUrl = portalUrl.endsWith('/')
        ? portalUrl.substring(0, portalUrl.length - 1)
        : portalUrl;
    final url = Uri.parse('$formattedUrl/login/token.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username.trim(),
          'password': password,
          'service': 'moodle_mobile_app',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('token')) {
          return data['token'].toString().trim();
        }
      }
    } catch (e) {
      debugPrint('[Moodle Auth Exception]: $e');
    }
    return null;
  }

  /// Calculates the Levenshtein distance between two strings (number of edits required).
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Calculates similarity score between two strings using normalized Levenshtein token matching.
  /// Returns a value between 0.0 (no match) and 1.0 (exact match).
  double _calculateSimilarity(String s1, String s2) {
    final clean1 = s1
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
    final clean2 = s2
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();

    if (clean1.isEmpty || clean2.isEmpty) return 0.0;
    if (clean1 == clean2) return 1.0;

    final tokens1 = clean1.split(RegExp(r'\s+'));
    final tokens2 = clean2.split(RegExp(r'\s+'));

    double maxScore = 0.0;

    // Check token-to-token similarity for course codes and title abbreviations
    for (var t1 in tokens1) {
      if (t1.length < 3) continue;
      for (var t2 in tokens2) {
        if (t2.length < 3) continue;
        final dist = _levenshteinDistance(t1, t2);
        final maxLen = max(t1.length, t2.length);
        final sim = 1.0 - (dist / maxLen);
        if (sim > maxScore) maxScore = sim;
      }
    }

    // Also compare full string distance for complete matches
    final fullDist = _levenshteinDistance(clean1, clean2);
    final fullMaxLen = max(clean1.length, clean2.length);
    final fullSim = 1.0 - (fullDist / fullMaxLen);

    return max(maxScore, fullSim);
  }

  /// Maps raw Moodle activities to the user's subjects using Levenshtein similarity.
  List<SubjectTaskData> mapMoodleActivitiesToSubjects({
    required List<Map<String, dynamic>> rawActivities,
    required List<SubjectTaskData> userSubjects,
  }) {
    if (rawActivities.isEmpty || userSubjects.isEmpty) return userSubjects;

    for (var raw in rawActivities) {
      final String rawCourseName = raw['course'] ?? '';
      final String rawTitle = raw['title'] ?? 'Moodle Task';
      final String description = raw['description'] ?? '';
      final DateTime dueDate = raw['dueDate'] as DateTime? ?? DateTime.now();
      final int duration = raw['durationMinutes'] as int? ?? 30;
      final String type = raw['type'] ?? 'Lesson';

      // Find best matching subject using Levenshtein distance
      SubjectTaskData targetSubject = userSubjects.first;
      double highestScore = -1.0;

      for (var subject in userSubjects) {
        final score = _calculateSimilarity(subject.name, rawCourseName);
        if (score > highestScore) {
          highestScore = score;
          targetSubject = subject;
        }
      }

      // Prevent duplicate insertion
      bool alreadyExists = targetSubject.taskList.any(
        (t) => t.title.trim().toLowerCase() == rawTitle.trim().toLowerCase(),
      );

      if (!alreadyExists) {
        targetSubject.taskList.add(
          TaskItem(
            id: raw['id'] ?? 'moodle_${DateTime.now().microsecondsSinceEpoch}',
            title: rawTitle,
            type: type,
            description: description,
            dueDate: dueDate,
            durationMinutes: duration,
            load: type == 'Assignment'
                ? TaskLoad.stressed
                : (type == 'Quiz' ? TaskLoad.meh : TaskLoad.good),
            subjectName: targetSubject.name,
          ),
        );
      }
    }

    return userSubjects;
  }

  /// Helper method for safe web service POST queries.
  Future<http.Response?> _safePost(
    String wsFunction,
    Map<String, String> bodyFields,
  ) async {
    final formattedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final url = Uri.parse('$formattedBaseUrl/webservice/rest/server.php');

    final Map<String, String> payload = {
      'wstoken': token.trim(),
      'wsfunction': wsFunction,
      'moodlewsrestformat': 'json',
      ...bodyFields,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      );
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      debugPrint('[Network EXCEPTION] $wsFunction: $e');
    }
    return null;
  }

  /// Primary method to fetch all course contents (Lessons, Quizzes, Assignments, Pages).
  /// Automatically filters out completed tasks based on Moodle's `completionstate`.
  Future<List<Map<String, dynamic>>> fetchMoodleActivities() async {
    List<Map<String, dynamic>> activities = [];

    try {
      final siteInfoRes = await _safePost('core_webservice_get_site_info', {});
      if (siteInfoRes == null) return _generateFallbackMockActivities();

      final siteData = jsonDecode(siteInfoRes.body);
      final int? userId = siteData['userid'];
      if (userId == null) return _generateFallbackMockActivities();

      final coursesRes = await _safePost('core_enrol_get_users_courses', {
        'userid': userId.toString(),
      });
      if (coursesRes == null) return _generateFallbackMockActivities();

      final dynamicCourses = jsonDecode(coursesRes.body);
      if (dynamicCourses is! List) return _generateFallbackMockActivities();

      for (var c in dynamicCourses) {
        if (c is Map && c['id'] != null) {
          int courseId = c['id'];
          String courseTitle = c['fullname'] ?? 'General';

          // 1. Query core_course_get_contents to discover ALL modules (Lessons, Pages, Resources)
          final contentsRes = await _safePost('core_course_get_contents', {
            'courseid': courseId.toString(),
          });

          if (contentsRes != null) {
            final dynamicSections = jsonDecode(contentsRes.body);
            if (dynamicSections is List) {
              for (var section in dynamicSections) {
                final modules = section['modules'] ?? [];
                for (var mod in modules) {
                  final String modName = mod['modname'] ?? '';
                  final String title = mod['name'] ?? '';
                  final int modId = mod['id'] ?? 0;

                  // Completion Filtering: state 1 (complete), 2 (complete pass)
                  final completionData = mod['completiondata'];
                  int completionState = 0;
                  if (completionData != null && completionData is Map) {
                    completionState = completionData['state'] ?? 0;
                  }

                  // Skip already completed activities
                  if (completionState == 1 || completionState == 2) {
                    continue;
                  }

                  // Determine Activity Type and Metadata
                  String activityType = 'Lesson';
                  int durationMinutes = 20;

                  if (modName == 'quiz' ||
                      title.toLowerCase().contains('quiz')) {
                    activityType = 'Quiz';
                    durationMinutes = 30;
                  } else if (modName == 'assign' ||
                      title.toLowerCase().contains('assignment')) {
                    activityType = 'Assignment';
                    durationMinutes = 60;
                  } else if (modName == 'lesson' ||
                      modName == 'page' ||
                      modName == 'resource') {
                    activityType = 'Lesson';
                    durationMinutes = 25;
                  } else {
                    // Skip non-actionable administrative modules
                    if (modName == 'forum' ||
                        modName == 'folder' ||
                        modName == 'label') {
                      continue;
                    }
                  }

                  // Standardize deadline to a fixed end-of-day target (23:59)
                  DateTime targetDate = _standardizeFixedDeadline(null);

                  activities.add({
                    'id': 'moodle_${modName}_$modId',
                    'title': title,
                    'course': courseTitle,
                    'type': activityType,
                    'dueDate': targetDate,
                    'durationMinutes': durationMinutes,
                    'description': _stripHtml(
                      mod['description'] ?? mod['intro'] ?? '',
                    ),
                  });
                }
              }
            }
          }

          // 2. Query mod_assign_get_assignments to enrich precise due dates if available
          final assignRes = await _safePost('mod_assign_get_assignments', {
            'courseids[0]': courseId.toString(),
          });
          if (assignRes != null) {
            final assignData = jsonDecode(assignRes.body);
            if (assignData is Map && assignData['courses'] != null) {
              for (var courseBlock in assignData['courses']) {
                for (var assign in (courseBlock['assignments'] ?? [])) {
                  final String assignId = 'moodle_assign_${assign['id']}';
                  final index = activities.indexWhere(
                    (a) => a['id'] == assignId,
                  );

                  if (assign['duedate'] != null && assign['duedate'] > 0) {
                    final rawDueDate = DateTime.fromMillisecondsSinceEpoch(
                      assign['duedate'] * 1000,
                    );
                    final fixedDate = _standardizeFixedDeadline(rawDueDate);

                    if (index != -1) {
                      activities[index]['dueDate'] = fixedDate;
                      activities[index]['description'] = _stripHtml(
                        assign['intro'] ?? '',
                      );
                    }
                  }
                }
              }
            }
          }

          // 3. Query mod_quiz_get_quizzes_by_courses to enrich quiz closing times
          final quizRes = await _safePost('mod_quiz_get_quizzes_by_courses', {
            'courseids[0]': courseId.toString(),
          });
          if (quizRes != null) {
            final quizData = jsonDecode(quizRes.body);
            if (quizData is Map && quizData['quizzes'] != null) {
              for (var quiz in quizData['quizzes']) {
                final String quizId = 'moodle_quiz_${quiz['id']}';
                final index = activities.indexWhere((a) => a['id'] == quizId);

                if (quiz['timeclose'] != null && quiz['timeclose'] > 0) {
                  final rawClose = DateTime.fromMillisecondsSinceEpoch(
                    quiz['timeclose'] * 1000,
                  );
                  final fixedDate = _standardizeFixedDeadline(rawClose);

                  if (index != -1) {
                    activities[index]['dueDate'] = fixedDate;
                    activities[index]['description'] = _stripHtml(
                      quiz['intro'] ?? '',
                    );
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Moodle pipeline error: $e');
    }

    if (activities.isEmpty) {
      return _generateFallbackMockActivities();
    }

    // Save timestamp for background hourly sync tracking
    await updateSyncTimestamp();

    return activities;
  }

  /// Converts timestamps into fixed, clean target dates (23:59) for student planning.
  DateTime _standardizeFixedDeadline(DateTime? rawDate) {
    final base = rawDate ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, 23, 59);
  }

  /// Removes HTML tags from Moodle descriptions.
  String _stripHtml(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  List<Map<String, dynamic>> _generateFallbackMockActivities() {
    final now = DateTime.now();
    return [
      {
        'id': 'moodle_fallback_1',
        'title': 'Lesson 1: Introduction to Data Structures',
        'course': 'Computer Science',
        'type': 'Lesson',
        'description':
            'Read chapter overview on arrays, linked lists, and stacks.',
        'dueDate': DateTime(now.year, now.month, now.day, 23, 59),
        'durationMinutes': 25,
      },
      {
        'id': 'moodle_fallback_2',
        'title': 'Quiz 1: Data Structures Overview',
        'course': 'Computer Science',
        'type': 'Quiz',
        'description':
            'Online quiz covering stacks, queues, and complexity analysis.',
        'dueDate': DateTime(now.year, now.month, now.day, 23, 59),
        'durationMinutes': 30,
      },
      {
        'id': 'moodle_fallback_3',
        'title': 'Assignment 2: Vector Calculus Set',
        'course': 'Mathematics',
        'type': 'Assignment',
        'description':
            'Complete exercises from chapter 4. Upload scan to Moodle.',
        'dueDate': DateTime(now.year, now.month, now.day, 23, 59),
        'durationMinutes': 60,
      },
    ];
  }

  /// Checks if 60 minutes have elapsed since the last Moodle API sync.
  static Future<bool> shouldSyncHourly() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final int sixtyMinutesInMs = 60 * 60 * 1000;

    return (now - lastSync) >= sixtyMinutesInMs;
  }

  /// Updates the stored timestamp of the last successful synchronization.
  static Future<void> updateSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('moodle_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moodle_token', token.trim());
  }

  static Future<void> clearSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moodle_token');
    await prefs.remove(_lastSyncKey);
  }

  /// Fetches enrolled courses directly from Moodle API, pulls all pending activities,
  /// maps them into SubjectTaskData instances, and assigns vibrant pastel colors.
  Future<List<SubjectTaskData>> fetchEnrolledSubjects({
    List<Color>? palette,
  }) async {
    final colors = palette ??
        const [
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

    List<SubjectTaskData> subjects = [];
    final rawActivities = await fetchMoodleActivities();

    // Group activities by course title
    final Map<String, List<TaskItem>> grouped = {};
    for (var act in rawActivities) {
      final course = (act['course'] as String? ?? 'General').trim();
      if (!grouped.containsKey(course)) {
        grouped[course] = [];
      }
      grouped[course]!.add(
        TaskItem(
          id: act['id'] ?? 'moodle_${DateTime.now().microsecondsSinceEpoch}',
          title: act['title'] ?? 'Task',
          type: act['type'] ?? 'Lesson',
          description: act['description'] ?? '',
          dueDate: act['dueDate'] as DateTime?,
          durationMinutes: act['durationMinutes'] as int? ?? 30,
          load: act['type'] == 'Assignment'
              ? TaskLoad.stressed
              : (act['type'] == 'Quiz' ? TaskLoad.meh : TaskLoad.good),
          subjectName: course,
        ),
      );
    }

    if (grouped.isEmpty) {
      return generateFallbackSubjects(colors);
    }

    int colorIndex = 0;
    grouped.forEach((courseName, tasks) {
      subjects.add(
        SubjectTaskData(
          name: courseName,
          customName: courseName,
          subjectColor: colors[colorIndex % colors.length],
          lessonDifficulty: 3,
          quizDifficulty: 3,
          assignmentDifficulty: 3,
          taskList: tasks,
        ),
      );
      colorIndex++;
    });

    return subjects;
  }

  /// Fallback curated subjects with rich sample tasks for offline mode / guest onboarding
  static List<SubjectTaskData> generateFallbackSubjects([List<Color>? palette]) {
    final colors = palette ??
        const [
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

    final now = DateTime.now();
    return [
      SubjectTaskData(
        name: 'Mathematics',
        customName: 'Pure Mathematics',
        subjectColor: colors[0],
        lessonDifficulty: 4,
        quizDifficulty: 4,
        assignmentDifficulty: 4,
        examDate: DateTime(now.year, now.month, now.day + 18),
        taskList: [
          TaskItem(
            id: 'mock_math_1',
            title: 'Vector Calculus Practice Problem Set',
            type: 'Assignment',
            description: 'Complete exercises 4.1 to 4.5. Upload PDF scan.',
            dueDate: DateTime(now.year, now.month, now.day + 2, 23, 59),
            durationMinutes: 60,
            load: TaskLoad.stressed,
            subjectName: 'Mathematics',
          ),
          TaskItem(
            id: 'mock_math_2',
            title: 'Quiz 2: Differential Equations',
            type: 'Quiz',
            dueDate: DateTime(now.year, now.month, now.day + 5, 23, 59),
            durationMinutes: 30,
            load: TaskLoad.meh,
            subjectName: 'Mathematics',
          ),
        ],
      ),
      SubjectTaskData(
        name: 'Computer Science',
        customName: 'CS: Data Structures',
        subjectColor: colors[5],
        lessonDifficulty: 3,
        quizDifficulty: 3,
        assignmentDifficulty: 4,
        examDate: DateTime(now.year, now.month, now.day + 24),
        taskList: [
          TaskItem(
            id: 'mock_cs_1',
            title: 'Lesson 3: Binary Search Trees',
            type: 'Lesson',
            dueDate: DateTime(now.year, now.month, now.day + 1, 23, 59),
            durationMinutes: 35,
            load: TaskLoad.good,
            subjectName: 'Computer Science',
          ),
          TaskItem(
            id: 'mock_cs_2',
            title: 'Programming Lab 1: Tree Traversals',
            type: 'Assignment',
            dueDate: DateTime(now.year, now.month, now.day + 4, 23, 59),
            durationMinutes: 75,
            load: TaskLoad.melting,
            subjectName: 'Computer Science',
          ),
        ],
      ),
      SubjectTaskData(
        name: 'Physics',
        customName: 'Physics Mechanics',
        subjectColor: colors[3],
        lessonDifficulty: 3,
        quizDifficulty: 4,
        assignmentDifficulty: 3,
        examDate: DateTime(now.year, now.month, now.day + 12),
        taskList: [
          TaskItem(
            id: 'mock_phys_1',
            title: 'Newtonian Dynamics Summary',
            type: 'Lesson',
            dueDate: DateTime(now.year, now.month, now.day + 3, 23, 59),
            durationMinutes: 25,
            load: TaskLoad.good,
            subjectName: 'Physics',
          ),
        ],
      ),
    ];
  }
}
