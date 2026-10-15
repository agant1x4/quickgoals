import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_models.dart';

class SubjectAnalysisItem {
  final String id;
  final String text;
  final String category;
  final bool isStrength;
  final DateTime dateAdded;

  SubjectAnalysisItem({
    required this.id,
    required this.text,
    this.category = 'Concept',
    required this.isStrength,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'category': category,
    'isStrength': isStrength,
    'dateAdded': dateAdded.toIso8601String(),
  };

  factory SubjectAnalysisItem.fromMap(Map<String, dynamic> map) =>
      SubjectAnalysisItem(
        id: map['id'] ?? '',
        text: map['text'] ?? '',
        category: map['category'] ?? 'Concept',
        isStrength: map['isStrength'] ?? false,
        dateAdded: DateTime.tryParse(map['dateAdded'] ?? '') ?? DateTime.now(),
      );
}

class WeaknessTrackerScreen extends StatefulWidget {
  final List<SubjectTaskData>? userSubjects;

  const WeaknessTrackerScreen({super.key, this.userSubjects});

  @override
  State<WeaknessTrackerScreen> createState() => _WeaknessTrackerScreenState();
}

class _WeaknessTrackerScreenState extends State<WeaknessTrackerScreen> {
  // QuickGoals Theme Matching Palette
  static const Color _bgCanvas = Color(0xFFF9FAFC);
  static const Color _darkText = Color(0xFF1E2841);
  static const Color _mutedText = Color(0xFF718096);
  static const Color _primaryOrange = Color(0xFFFFB75E);
  static const Color _strengthGreen = Color(0xFF53C580);
  static const Color _strengthBg = Color(0xFFE8F8EE);
  static const Color _weaknessCoral = Color(0xFFFF6B6B);
  static const Color _weaknessBg = Color(0xFFFFEAEA);

  List<String> _availableSubjects = [
    'Computer Science',
    'Mathematics',
    'Physics',
  ];
  late String _selectedSubject;

  Map<String, List<SubjectAnalysisItem>> _analysisData = {};

  final TextEditingController _strengthInputController =
      TextEditingController();
  final TextEditingController _weaknessInputController =
      TextEditingController();

  String _selectedStrengthCategory = 'Concept';
  String _selectedWeaknessCategory = 'Concept';

  final List<String> _categories = [
    'Concept',
    'Speed & Timing',
    'Exam Prep',
    'Problem Solving',
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _strengthInputController.dispose();
    _weaknessInputController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    List<String> loadedSubjectNames = [];

    if (widget.userSubjects != null && widget.userSubjects!.isNotEmpty) {
      loadedSubjectNames = widget.userSubjects!.map((s) => s.name).toList();
    } else {
      final cachedJson = prefs.getString('quickgoals_user_subjects');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedJson);
          final subjects = decoded
              .map((e) => SubjectTaskData.fromMap(e as Map<String, dynamic>))
              .toList();
          loadedSubjectNames = subjects.map((s) => s.name).toList();
        } catch (e) {
          debugPrint('Error decoding user subjects: $e');
        }
      }
    }

    if (loadedSubjectNames.isNotEmpty) {
      _availableSubjects = loadedSubjectNames.toSet().toList();
    }

    _selectedSubject = _availableSubjects.first;

    final rawData = prefs.getString('quickgoals_weakness_tracker_data');
    if (rawData != null && rawData.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(rawData);
        Map<String, List<SubjectAnalysisItem>> loadedMap = {};
        decoded.forEach((key, value) {
          if (value is List) {
            loadedMap[key] = value
                .map(
                  (e) => SubjectAnalysisItem.fromMap(e as Map<String, dynamic>),
                )
                .toList();
          }
        });
        _analysisData = loadedMap;
      } catch (e) {
        debugPrint('Error loading weakness tracker items: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> serializableMap = {};
    _analysisData.forEach((key, list) {
      serializableMap[key] = list.map((item) => item.toMap()).toList();
    });
    await prefs.setString(
      'quickgoals_weakness_tracker_data',
      jsonEncode(serializableMap),
    );
  }

  void _addItem({required bool isStrength}) {
    final controller = isStrength
        ? _strengthInputController
        : _weaknessInputController;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final category = isStrength
        ? _selectedStrengthCategory
        : _selectedWeaknessCategory;

    final newItem = SubjectAnalysisItem(
      id: 'item_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      category: category,
      isStrength: isStrength,
      dateAdded: DateTime.now(),
    );

    setState(() {
      _analysisData.putIfAbsent(_selectedSubject, () => []);
      _analysisData[_selectedSubject]!.add(newItem);
      controller.clear();
    });

    _saveData();
  }

  void _removeItem(String itemId) {
    setState(() {
      if (_analysisData.containsKey(_selectedSubject)) {
        _analysisData[_selectedSubject]!.removeWhere(
          (item) => item.id == itemId,
        );
      }
    });
    _saveData();
  }

  void _toggleItemStatus(String itemId) {
    setState(() {
      if (_analysisData.containsKey(_selectedSubject)) {
        final list = _analysisData[_selectedSubject]!;
        final index = list.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          final current = list[index];
          list[index] = SubjectAnalysisItem(
            id: current.id,
            text: current.text,
            category: current.category,
            isStrength: !current.isStrength,
            dateAdded: current.dateAdded,
          );
        }
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryOrange),
              )
            : Column(
                children: [
                  _buildHeaderBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20.0,
                        12.0,
                        20.0,
                        90.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubjectSelectorCard(),
                          const SizedBox(height: 18),
                          _buildSummaryOverviewBar(),
                          const SizedBox(height: 24),

                          // STRENGTHS SECTION
                          _buildSectionHeader(
                            title: 'Mastered Concepts & Strengths',
                            subtitle: 'Topics you feel confident in',
                            accentColor: _strengthGreen,
                            icon: Icons.trending_up_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildInlineLoggerCard(isStrength: true),
                          const SizedBox(height: 14),
                          _buildItemList(isStrength: true),

                          const SizedBox(height: 28),

                          // WEAKNESSES SECTION
                          _buildSectionHeader(
                            title: 'Focus Areas & Weaknesses',
                            subtitle: 'Concepts requiring revision',
                            accentColor: _weaknessCoral,
                            icon: Icons.adjust_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildInlineLoggerCard(isStrength: false),
                          const SizedBox(height: 14),
                          _buildItemList(isStrength: false),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skill & Weakness Logger',
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              Text(
                'Track strengths & targeted growth areas',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelectorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.book, color: _primaryOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT SUBJECT',
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _mutedText,
                    letterSpacing: 0.5,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubject,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _darkText,
                    ),
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                    items: _availableSubjects.map((String subject) {
                      return DropdownMenuItem<String>(
                        value: subject,
                        child: Text(subject),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSubject = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryOverviewBar() {
    final items = _analysisData[_selectedSubject] ?? [];
    final strengthsCount = items.where((i) => i.isStrength).length;
    final weaknessesCount = items.where((i) => !i.isStrength).length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _strengthBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: _strengthGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$strengthsCount Strengths',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    Text(
                      'Mastered',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _weaknessBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: _weaknessCoral,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$weaknessesCount Focus Areas',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    Text(
                      'To Practice',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        color: _mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _mutedText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInlineLoggerCard({required bool isStrength}) {
    final accentColor = isStrength ? _strengthGreen : _weaknessCoral;
    final controller = isStrength
        ? _strengthInputController
        : _weaknessInputController;
    final selectedCategory = isStrength
        ? _selectedStrengthCategory
        : _selectedWeaknessCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final bool isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : _darkText,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accentColor,
                    backgroundColor: _bgCanvas,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          if (isStrength) {
                            _selectedStrengthCategory = cat;
                          } else {
                            _selectedWeaknessCategory = cat;
                          }
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                  ),
                  decoration: InputDecoration(
                    hintText: isStrength
                        ? 'e.g. Mastered dynamic programming...'
                        : 'e.g. Need practice with binary search trees...',
                    hintStyle: GoogleFonts.quicksand(
                      fontSize: 13,
                      color: _mutedText,
                    ),
                    filled: true,
                    fillColor: _bgCanvas,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addItem(isStrength: isStrength),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _addItem(isStrength: isStrength),
                  child: Text(
                    'Log',
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemList({required bool isStrength}) {
    final allSubjectItems = _analysisData[_selectedSubject] ?? [];
    final filteredItems = allSubjectItems
        .where((i) => i.isStrength == isStrength)
        .toList();

    if (filteredItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          isStrength
              ? 'No strengths logged yet for $_selectedSubject.'
              : 'No focus areas logged yet for $_selectedSubject.',
          textAlign: TextAlign.center,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            color: _mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final accentColor = isStrength ? _strengthGreen : _weaknessCoral;

    return Column(
      children: filteredItems.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category,
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.text,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _toggleItemStatus(item.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isStrength
                        ? _strengthGreen.withValues(alpha: 0.1)
                        : _primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStrength
                            ? Icons.check_circle_rounded
                            : Icons.trending_up_rounded,
                        color: isStrength ? _strengthGreen : _primaryOrange,
                        size: 16,
                      ),
                      if (!isStrength) ...[
                        const SizedBox(width: 4),
                        Text(
                          'Mastered',
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _darkText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: _mutedText,
                  size: 18,
                ),
                onPressed: () => _removeItem(item.id),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
