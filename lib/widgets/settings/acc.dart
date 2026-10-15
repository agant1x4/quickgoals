import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountSettingsView extends StatefulWidget {
  final List<String> moodleFilters;
  final ValueChanged<List<String>> onFiltersChanged;
  final VoidCallback onBack;

  const AccountSettingsView({
    super.key,
    required this.moodleFilters,
    required this.onFiltersChanged,
    required this.onBack,
  });

  @override
  State<AccountSettingsView> createState() => _AccountSettingsViewState();
}

class _AccountSettingsViewState extends State<AccountSettingsView> {
  String _activeAccountForm = 'moodle'; // 'details' or 'moodle'

  final TextEditingController _moodleIdentifierController = TextEditingController();
  final TextEditingController _moodlePasswordController = TextEditingController();
  final TextEditingController _keyphraseFilterController = TextEditingController();

  final Color brandOrange = const Color(0xFFFF9F43);

  @override
  void dispose() {
    _moodleIdentifierController.dispose();
    _moodlePasswordController.dispose();
    _keyphraseFilterController.dispose();
    super.dispose();
  }

  void _addFilter() {
    final text = _keyphraseFilterController.text.trim();
    if (text.isNotEmpty && !widget.moodleFilters.contains(text)) {
      final updatedList = List<String>.from(widget.moodleFilters)..add(text);
      widget.onFiltersChanged(updatedList);
      _keyphraseFilterController.clear();
    }
  }

  void _removeFilter(String filter) {
    final updatedList = List<String>.from(widget.moodleFilters)..remove(filter);
    widget.onFiltersChanged(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Text(
                'Account Settings',
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-navigation Switcher
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Details')),
                  selected: _activeAccountForm == 'details',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeAccountForm = 'details');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Moodle')),
                  selected: _activeAccountForm == 'moodle',
                  onSelected: (selected) {
                    if (selected) setState(() => _activeAccountForm = 'moodle');
                  },
                ),
              ),
            ],
          ),

          // Render active sub-form
          if (_activeAccountForm == 'details')
            _buildDetailsForm(cardColor)
          else
            _buildMoodleForm(cardColor),
        ],
      ),
    );
  }

  Widget _buildDetailsForm(Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Column(
        children: [
          Text(
            'Personal Details',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodleForm(Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _moodleIdentifierController,
            decoration: InputDecoration(
              hintText: 'Moodle username',
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: brandOrange),
              ),
            ),
            style: GoogleFonts.quicksand(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _moodlePasswordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Moodle password...',
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: brandOrange),
              ),
            ),
            style: GoogleFonts.quicksand(),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 140,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  // Save Moodle credentials logic
                },
                child: Text(
                  'Save',
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Filters',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.moodleFilters.map((filter) {
              return Chip(
                label: Text(
                  filter,
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFFA1887F),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                onDeleted: () => _removeFilter(filter),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Provide a keyphrase/course that Quickgoals should not pull from Moodle.',
            style: GoogleFonts.quicksand(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyphraseFilterController,
            decoration: InputDecoration(
              labelText: 'Keyphrase/course',
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: brandOrange),
              ),
            ),
            style: GoogleFonts.quicksand(),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 140,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _addFilter,
                child: Text(
                  'Filter!',
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}