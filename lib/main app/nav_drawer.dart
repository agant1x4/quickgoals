import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddPressed;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Navigation items directly matching your mockup design
    final navItems = const [
      Icons.dashboard_rounded, // 0: Dashboard
      Icons.timer_rounded, // 1: Focus Timer
      Icons.psychology_rounded, // 2: Weakness Tracker
      Icons.calendar_view_day, // 3: Calendar / Schedule
      Icons.settings_rounded, // 4: Settings
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // --- MAIN FROSTED NAVIGATION CAPSULE ---
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ).withOpacity(0.75),
                          const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ).withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(36.0),

                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(navItems.length, (index) {
                        final isSelected = index == currentIndex;

                        return GestureDetector(
                          onTap: () => onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 56 : 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFB2C4F6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22.0),
                            ),
                            child: Center(
                              child: Icon(
                                navItems[index],
                                size: 24,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF222222),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // --- SEPARATE QUICK ADD BUTTON (+) ---
            GestureDetector(
              onTap: onAddPressed,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB766),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        5,
                        5,
                        5,
                      ).withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
