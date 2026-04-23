import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../utils/time_utils.dart';
import '../settings/user_profile_screen.dart';
import '../dashboard/breathing_lotus.dart';

// ─── Task Model ─────────────────────────────────────────────────────────────
class TaskItem {
  String title;
  bool isCompleted;
  IconData icon;
  int? durationMinutes; // null = no timer
  TaskItem(this.title, {this.isCompleted = false, this.icon = Icons.check_circle_outline, this.durationMinutes});
}

// ─── Wellness Timer Dialog ───────────────────────────────────────────────────
class _WellnessTimerDialog extends StatefulWidget {
  final TaskItem task;
  const _WellnessTimerDialog({required this.task});
  @override
  State<_WellnessTimerDialog> createState() => _WellnessTimerDialogState();
}

class _WellnessTimerDialogState extends State<_WellnessTimerDialog>
    with SingleTickerProviderStateMixin {
  late int _secondsLeft;
  Timer? _timer;
  bool _running = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _secondsLeft = (widget.task.durationMinutes ?? 5) * 60;
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 0) {
          t.cancel();
          setState(() => _running = false);
          Navigator.of(context).pop(true); // completed
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  String get _timeStr {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final total = (widget.task.durationMinutes ?? 5) * 60;
    final progress = 1.0 - (_secondsLeft / total);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.task.icon, size: 40, color: primary),
          const SizedBox(height: 12),
          Text(widget.task.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 24),
          SizedBox(
            width: 140, height: 140,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: primary.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Text(_timeStr,
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold,
                      color: primary.withOpacity(0.7 + _pulse.value * 0.3),
                    )),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? 'Pause' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _usageLimitHours = 5;
  double _screenTimeHours = 0.0;
  bool _isLoadingUsage = true;
  Map<String, double> _topApps = {};

  bool _isLoadingInsight = true;
  String _aiInsight = "Analyzing your digital habits...";

  String _username = 'CloudyKid';
  int _age = 18;
  String _focusGoal = 'Reduce social media usage';

  int _unlockCount = 0;
  double _addictionScore = 0.0;
  int _currentStreak = 0;

  final List<TaskItem> _tasks = [
    TaskItem('Music Therapy', icon: Icons.music_note, durationMinutes: 5),
    TaskItem('Breathing Exercise', icon: Icons.air, durationMinutes: 3),
    TaskItem('1-Hour Deep Work Block', icon: Icons.work_outline),
    TaskItem('Digital Sunset at 9 PM', icon: Icons.bedtime_outlined),
  ];

  Widget _quickStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // Time-aware greeting
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadData().then((_) => _fetchAIInsight());
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _username = prefs.getString('username') ?? 'CloudyKid';
        _age = prefs.getInt('age') ?? 18;
        _focusGoal = prefs.getString('focusGoal') ?? 'Reduce social media usage';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _usageLimitHours = prefs.getInt('usageLimitHours') ?? 5;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;

      const platform = MethodChannel('com.luminance/usage');
      
      double totalHours = await platform.invokeMethod('getForegroundScreenTime') ?? 0.0;
      _unlockCount = await platform.invokeMethod('getUnlockCount') ?? 0;

      // Basic addiction score calculation (Usage + Unlocks)
      double usageScore = (totalHours / _usageLimitHours.toDouble()) * 70.0;
      double unlockScore = (_unlockCount / 50.0) * 30.0;
      _addictionScore = (usageScore + unlockScore).clamp(5.0, 100.0);

      // Try to get per-app usage
      Map<dynamic, dynamic>? appUsage;
      try {
        appUsage = await platform.invokeMethod('getTopAppUsage');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _screenTimeHours = totalHours;
          _isLoadingUsage = false;
          if (appUsage != null) {
            _topApps = appUsage.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingUsage = false; });
    }
  }

  Future<void> _fetchAIInsight() async {
    if (!mounted) return;
    setState(() => _isLoadingInsight = true);

    const apiKey = 'YOUR_GROQ_KEY_HERE';
    const endpoint = 'https://api.groq.com/openai/v1/chat/completions';

    // Build app usage context string
    String appContext = '';
    if (_topApps.isNotEmpty) {
      final sorted = _topApps.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top3 = sorted.take(3).map((e) => '${e.key} (${e.value.toStringAsFixed(1)}h)').join(', ');
      appContext = ' Most used apps today: $top3.';
    }

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are DigiGuide, a concise, empathetic digital wellbeing coach. Give a 2-sentence personalized insight based on the user's screen time and app usage. Be specific about which apps and suggest one actionable tip."
            },
            {
              "role": "user",
              "content":
                  "My name is $_username, age $_age. Focus goal: $_focusGoal. Screen time today: ${_screenTimeHours.toStringAsFixed(1)}h out of ${_usageLimitHours}h limit.$appContext Give me a personalized insight."
            }
          ],
          "temperature": 0.75,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'];
        if (mounted) setState(() { _aiInsight = reply.trim(); _isLoadingInsight = false; });
      } else {
        print("Groq Home Error: ${response.statusCode} ${response.body}");
        if (mounted) setState(() { _aiInsight = "Stay mindful of your screen time and take regular breaks today."; _isLoadingInsight = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _aiInsight = "Take a break and reconnect with the present moment today."; _isLoadingInsight = false; });
    }
  }

  void _toggleTask(int index) {
    final task = _tasks[index];
    if (task.durationMinutes != null && !task.isCompleted) {
      // Open timer dialog for wellness tasks
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WellnessTimerDialog(task: task),
      ).then((completed) {
        if (completed == true) {
          setState(() => _tasks[index].isCompleted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${task.title} completed! Great job 🎉'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      });
    } else {
      setState(() => _tasks[index].isCompleted = !_tasks[index].isCompleted);
    }
  }

  // ── Profile Bottom Sheet ──────────────────────────────────────────────────
  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileBottomSheet(
        username: _username,
        age: _age,
        focusGoal: _focusGoal,
        usageLimitHours: _usageLimitHours,
        onOpenProfile: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserProfileScreen()),
          ).then((_) { _loadData(); _loadProfile(); });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luminance'),
        leading: IconButton(
          icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: primary),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        actions: [
          GestureDetector(
            onTap: _showProfileSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_circle, color: primary, size: 20),
                  const SizedBox(width: 6),
                  Text(_username,
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadData(); await _fetchAIInsight(); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──────────────────────────────────────────────
                Text(
                  _greeting,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.65),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _username,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Screen Time Card ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary.withOpacity(0.2), Theme.of(context).cardTheme.color ?? Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primary.withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    Text("Today's Screen Time",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16, fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 16),
                    _isLoadingUsage
                        ? const Padding(padding: EdgeInsets.all(54), child: CircularProgressIndicator())
                        : Stack(alignment: Alignment.center, children: [
                            BreathingLotus(size: 140, color: primary),
                            SizedBox(
                              width: 140, height: 140,
                              child: CircularProgressIndicator(
                                value: _usageLimitHours > 0
                                    ? (_screenTimeHours / _usageLimitHours).clamp(0.0, 1.0)
                                    : 0,
                                backgroundColor: isDark ? AppTheme.darkBlue : Theme.of(context).scaffoldBackgroundColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _screenTimeHours >= _usageLimitHours ? Colors.redAccent : primary,
                                ),
                                strokeWidth: 12,
                              ),
                            ),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                TimeUtils.formatMinutes(_screenTimeHours * 60),
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 22, fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('of ${TimeUtils.formatMinutes(_usageLimitHours * 60.0)} limit',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    fontSize: 10,
                                  )),
                            ]),
                          ]),
                  ]),
                ),
                const SizedBox(height: 16),
                
                // ── Quick Stats Row ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _quickStatCard(context, 'Unlocks', '$_unlockCount', Icons.lock_open, Colors.blueAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStatCard(context, 'Risk', '${_addictionScore.round()}%', Icons.psychology, Colors.purpleAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickStatCard(context, 'Streak', '$_currentStreak', Icons.local_fire_department, Colors.orangeAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── DigiGuide Insight ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: isDark ? Border.all(color: primary.withOpacity(0.2)) : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.auto_awesome, color: primary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DigiGuide Insight',
                                style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (!_isLoadingInsight)
                              GestureDetector(
                                onTap: _fetchAIInsight,
                                child: Icon(Icons.refresh, color: primary, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isLoadingInsight
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 8),
                                Text('Analyzing your app usage patterns...',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                      fontSize: 12,
                                    )),
                              ])
                            : Text(
                                _aiInsight,
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 14, height: 1.5,
                                ),
                              ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Tasks For The Day ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tasks For The Day',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 20, fontWeight: FontWeight.bold,
                        )),
                    Text(
                      '${_tasks.where((t) => t.isCompleted).length}/${_tasks.length}',
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _tasks.isEmpty ? 0 : _tasks.where((t) => t.isCompleted).length / _tasks.length,
                    minHeight: 6,
                    backgroundColor: primary.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_tasks.length, (i) => _buildTaskItem(_tasks[i], i, primary, context)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(TaskItem task, int index, Color primary, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTimer = task.durationMinutes != null;

    return GestureDetector(
      onTap: () => _toggleTask(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: task.isCompleted
              ? primary.withOpacity(0.08)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: task.isCompleted ? primary.withOpacity(0.4) : Colors.transparent)
              : Border.all(color: task.isCompleted ? primary.withOpacity(0.3) : Colors.grey.shade300),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? primary.withOpacity(0.15)
                  : primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              task.icon,
              color: task.isCompleted ? primary : primary.withOpacity(0.6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                task.title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 15, fontWeight: FontWeight.w500,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              if (hasTimer && !task.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${task.durationMinutes} min session • Tap to start',
                    style: TextStyle(color: primary.withOpacity(0.7), fontSize: 11),
                  ),
                ),
              if (task.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('Completed ✓',
                      style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
          Icon(
            task.isCompleted ? Icons.check_circle : (hasTimer ? Icons.play_circle_outline : Icons.radio_button_unchecked),
            color: task.isCompleted ? primary : (hasTimer ? primary.withOpacity(0.6) : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
            size: 26,
          ),
        ]),
      ),
    );
  }
}

// ─── Profile Bottom Sheet ─────────────────────────────────────────────────────
class _ProfileBottomSheet extends StatelessWidget {
  final String username;
  final int age;
  final String focusGoal;
  final int usageLimitHours;
  final VoidCallback onOpenProfile;

  const _ProfileBottomSheet({
    required this.username,
    required this.age,
    required this.focusGoal,
    required this.usageLimitHours,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E2A3A) : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(height: 24),

        // Avatar + Name
        CircleAvatar(
          radius: 40,
          backgroundColor: primary.withOpacity(0.15),
          child: Icon(Icons.person, size: 44, color: primary),
        ),
        const SizedBox(height: 12),
        Text(username,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 4),
        Text('Digital Wellbeing Member',
            style: TextStyle(fontSize: 13, color: primary)),
        const SizedBox(height: 24),

        // Info Rows
        _infoRow(context, Icons.cake_outlined, 'Age', '$age years old', primary),
        _infoRow(context, Icons.flag_outlined, 'Focus Goal', focusGoal, primary),
        _infoRow(context, Icons.timer_outlined, 'Daily Limit', '$usageLimitHours hours/day', primary),
        _infoRow(context, Icons.lock_clock, 'Limit Policy', 'Locked for 15 days after setting', primary, isLast: true),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('View & Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, Color primary, {bool isLast = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(isDark ? 0.15 : 0.2)),
        ),
      ),
      child: Row(children: [
        Icon(icon, color: primary, size: 20),
        const SizedBox(width: 14),
        Text('$label  ',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 13,
            )),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600, fontSize: 13,
              )),
        ),
      ]),
    );
  }
}
