/// Represents the mental effort / mood associated with a task.
/// Used for both Cognitive Load calculation (Burnout) and Task Weight (Streak).
enum TaskLoad {
  excited,
  good,
  meh,
  stressed,
  melting,
}

extension TaskLoadExtension on TaskLoad {
  /// Cognitive & Streak weighting multiplier derived from your design formula:
  /// 😆 Excited  = 0.75
  /// 😃 Good     = 1.00
  /// 🫥 Meh      = 1.25
  /// 😳 Stressed = 1.50
  /// 🫠 Melting  = 1.75
  double get multiplier {
    switch (this) {
      case TaskLoad.excited:
        return 0.75;
      case TaskLoad.good:
        return 1.0;
      case TaskLoad.meh:
        return 1.25;
      case TaskLoad.stressed:
        return 1.5;
      case TaskLoad.melting:
        return 1.75;
    }
  }

  /// Display emoji icon corresponding to the energy state
  String get emoji {
    switch (this) {
      case TaskLoad.excited:
        return '😆';
      case TaskLoad.good:
        return '😃';
      case TaskLoad.meh:
        return '🫥';
      case TaskLoad.stressed:
        return '😳';
      case TaskLoad.melting:
        return '🫠';
    }
  }

  /// Readable name for UI display
  String get label {
    switch (this) {
      case TaskLoad.excited:
        return 'Excited';
      case TaskLoad.good:
        return 'Good';
      case TaskLoad.meh:
        return 'Meh';
      case TaskLoad.stressed:
        return 'Stressed';
      case TaskLoad.melting:
        return 'Melting';
    }
  }

  /// True if the load is considered high-stress (Stressed 😳 or Melting 🫠)
  bool get isDreadedLoad => multiplier >= 1.5;
}