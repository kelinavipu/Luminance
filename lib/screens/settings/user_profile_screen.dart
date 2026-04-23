import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Profile fields
  final _usernameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _selectedGoal = 'Reduce social media usage';

  // Wellbeing limit
  final _limitCtrl = TextEditingController();
  int _usageLimitHours = 5;
  bool _isLocked = false;
  int _daysRemaining = 0;

  final List<String> _focusGoals = [
    'Reduce social media usage',
    'Improve sleep by reducing screen time',
    'Be more present with family & friends',
    'Increase daily productivity',
    'Reduce gaming addiction',
    'Build a healthier digital lifestyle',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _ageCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Profile
    final username = prefs.getString('username') ?? 'CloudyKid';
    final age = prefs.getInt('age') ?? 18;
    final goal = prefs.getString('focusGoal') ?? 'Reduce social media usage';

    // Limit
    final limit = prefs.getInt('usageLimitHours') ?? 5;
    final timestampStr = prefs.getString('limitLastSet');

    bool locked = false;
    int daysLeft = 0;
    if (timestampStr != null) {
      final lastSet = DateTime.parse(timestampStr);
      final diff = DateTime.now().difference(lastSet);
      if (diff.inDays < 15) {
        locked = true;
        daysLeft = 15 - diff.inDays;
      }
    }

    if (mounted) {
      setState(() {
        _usernameCtrl.text = username;
        _ageCtrl.text = age.toString();
        _selectedGoal = _focusGoals.contains(goal) ? goal : _focusGoals.first;
        _usageLimitHours = limit;
        _limitCtrl.text = limit.toString();
        _isLocked = locked;
        _daysRemaining = daysLeft;
      });
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    if (username.isEmpty) {
      _showSnack('Please enter a valid username.');
      return;
    }
    if (age == null || age < 5 || age > 120) {
      _showSnack('Please enter a valid age.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setInt('age', age);
    await prefs.setString('focusGoal', _selectedGoal);
    _showSnack('Profile saved successfully!', success: true);
  }

  Future<void> _saveLimit() async {
    final newLimit = int.tryParse(_limitCtrl.text);
    if (newLimit == null || newLimit <= 0) {
      _showSnack('Please enter a valid number of hours.');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usageLimitHours', newLimit);
    await prefs.setString('limitLastSet', DateTime.now().toIso8601String());
    setState(() {
      _usageLimitHours = newLimit;
      _isLocked = true;
      _daysRemaining = 15;
    });
    _showSnack('Limit locked for 15 days!', success: true);
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Theme.of(context).colorScheme.primary : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Avatar ────────────────────────────────────────────────────
          Center(
            child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: primary.withOpacity(0.18),
                child: Icon(Icons.person, size: 56, color: primary),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ]),
          ),
          const SizedBox(height: 32),

          // ── Profile Section ──────────────────────────────────────────
          _sectionLabel('PROFILE INFO', primary),
          const SizedBox(height: 12),
          _card(context, isDark, primary, children: [

            // Username
            _fieldLabel('Username'),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameCtrl,
              decoration: _inputDecor('e.g. CloudyKid', isDark),
            ),
            const SizedBox(height: 16),

            // Age
            _fieldLabel('Age'),
            const SizedBox(height: 8),
            TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecor('e.g. 18', isDark),
            ),
            const SizedBox(height: 16),

            // Focus Goal
            _fieldLabel('Focus Goal'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGoal,
              dropdownColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
              decoration: _inputDecor('Select a goal', isDark),
              items: _focusGoals.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedGoal = v); },
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 28),

          // ── Digital Wellbeing Limits ──────────────────────────────────
          _sectionLabel('DIGITAL WELLBEING', primary),
          const SizedBox(height: 12),
          _card(context, isDark, primary, children: [

            _fieldLabel('Daily Screen Time Limit (Hours)'),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: TextField(
                  controller: _limitCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !_isLocked,
                  decoration: _inputDecor('e.g. 4', isDark),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLocked ? null : _saveLimit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Set Limit'),
              ),
            ]),
            const SizedBox(height: 14),

            if (_isLocked)
              _statusRow(Icons.lock, Colors.orange,
                  'Strict limit active — cannot be changed for $_daysRemaining more day${_daysRemaining == 1 ? '' : 's'}.')
            else
              _statusRow(Icons.warning_amber_rounded, Colors.redAccent,
                  'Warning: Once set, this limit cannot be changed for 15 days.'),
          ]),

          const SizedBox(height: 32),

          // ── Stats Summary ─────────────────────────────────────────────
          _sectionLabel('QUICK SUMMARY', primary),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statCard(context, primary, '${_usageLimitHours}h', 'Daily Limit')),
            const SizedBox(width: 12),
            Expanded(child: _statCard(context, primary, _isLocked ? '$_daysRemaining days' : 'Unlocked', 'Lock Status')),
            const SizedBox(width: 12),
            Expanded(child: _statCard(context, primary, _ageCtrl.text.isNotEmpty ? '${_ageCtrl.text}y' : '--', 'Age')),
          ]),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label, Color primary) => Text(label,
      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.4));

  Widget _fieldLabel(String label) => Text(label,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
        fontSize: 13, fontWeight: FontWeight.w600,
      ));

  InputDecoration _inputDecor(String hint, bool isDark) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    fillColor: isDark ? const Color(0xFF0B1120) : Colors.white,
    filled: true,
  );

  Widget _card(BuildContext context, bool isDark, Color primary,
      {required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _statusRow(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
    ],
  );

  Widget _statCard(BuildContext context, Color primary, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: primary.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontSize: 11,
          )),
    ]),
  );
}
