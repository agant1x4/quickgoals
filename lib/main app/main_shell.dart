import 'package:flutter/material.dart';
import 'dashboard_phone.dart';
import 'pomodoro.dart';
import 'weakness_tracker.dart';
import 'review.dart';
import 'settings.dart';
import 'nav_drawer.dart';
import '../models/task_models.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentNavIndex = 0;
  List<SubjectTaskData> _userSubjects = [];

  void _handleQuickAdd(BuildContext context) {
    switch (_currentNavIndex) {
      case 0: // Dashboard -> Quick Goal / Task creation
        _showDashboardAddSheet(context);
        break;
      case 1: // Focus Timer -> Quick Pomodoro Preset
        _showPomodoroAddSheet(context);
        break;
      case 2: // Weakness Tracker -> Add Subject
        _showWeaknessTrackerAddSheet(context);
        break;
      case 3: // Review / Calendar -> Add Event
        _showReviewAddSheet(context);
        break;
      case 4: // Settings -> Trigger page action (e.g. Filter Modal)
        _showSettingsAddSheet(context);
        break;
    }
  }

  // --- Dynamic Action Handlers per Tab ---
  void _showDashboardAddSheet(BuildContext context) {
    // Placeholder for Dashboard Quick Add action
  }

  void _showPomodoroAddSheet(BuildContext context) {
    // Placeholder for Focus Timer Quick Add action
  }

  void _showWeaknessTrackerAddSheet(BuildContext context) {
    // Placeholder for Weakness Tracker Quick Add action
  }

  void _showReviewAddSheet(BuildContext context) {
    // Placeholder for Review / Calendar Quick Add action
  }

  void _showSettingsAddSheet(BuildContext context) {
    // Placeholder for Settings action (e.g. opening keyphrase filter modal)
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DashboardScreen(),
      PomodoroPage(userSubjects: _userSubjects),
      const WeaknessTrackerScreen(),
      const ReviewPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // LAYER 1: Active Page Stack
          IndexedStack(index: _currentNavIndex, children: pages),

          // LAYER 2: Floating Nav Drawer Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                setState(() {
                  _currentNavIndex = index;
                });
              },
              onAddPressed: () => _handleQuickAdd(context),
            ),
          ),
        ],
      ),
    );
  }
}
