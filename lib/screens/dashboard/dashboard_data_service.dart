import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminance/utils/firestore_service.dart';

class DashboardDataService {
  static final DashboardDataService _instance = DashboardDataService._internal();
  factory DashboardDataService() => _instance;
  DashboardDataService._internal();

  static const MethodChannel _channel = MethodChannel('com.luminance/usage');
  static const String _groqKey = 'YOUR_GROQ_KEY_HERE';
  
  // Native & Weekly Metrics
  double totalScreenTimeHours = 0.0;
  int unlockCount = 0;
  int nightAppsOpened = 0;
  bool isNightPassive = true;
  List<double> weeklyUsageHours = [];
  List<double> weeklyGuiltIndices = [];
  double weeklyAvgUsage = 0.0;
  double weeklyAvgGuilt = 0.0;
  Map<String, double> topAppUsage = {};
  Map<String, double> categoryBreakdown = {};

  // Presence & Glow Metrics
  List<bool> presenceMatrix = [true, true, false, true, true, true, true]; // Last 7 days
  int currentStreak = 0;
  int maxStreak = 0;
  int totalTasksCompleted = 0;
  int glowDays = 0; 
  int usageLimitHours = 5;
  
  // Penalty System
  double penaltyScore = 0.0;
  List<String> violations = [];
  Map<String, double> penaltyBreakdown = {};
  String aiInference = "Analyzing habits...";
  String mlAiInference = "Crunching data...";

  List<Map<String, dynamic>> dailyTasks = [];
  double guiltIndex = 0.0;

  Future<void> loadAllData() async {
    await _loadNativeData();
    await _loadStreaksAndTasks();
    await _loadWeeklyTrendsFromFirestore(); // Load historical labels/data
    _calculateGuiltIndex();
    _categorizeApps();
    _calculatePenaltyScore();
    await _allocateDailyTasks();
    await _checkAppBlocks();
    _syncToCloud();
  }

  Map<String, double> appWeeklyAverages = {};

  Future<void> _loadWeeklyTrendsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final query = await FirebaseFirestore.instance
          .collection('usageHistory')
          .where('userId', isEqualTo: user.uid)
          .get();

      final docs = query.docs;
      // Sort locally with safety check for missing timestamp
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTimestamp = (aData.containsKey('timestamp') ? aData['timestamp'] : Timestamp.now()) as Timestamp;
        final bTimestamp = (bData.containsKey('timestamp') ? bData['timestamp'] : Timestamp.now()) as Timestamp;
        return aTimestamp.compareTo(bTimestamp);
      });

      final recentDocs = docs.length > 7 ? docs.sublist(docs.length - 7) : docs;
      weeklyUsageHours = recentDocs.map((d) => (d.data().containsKey('totalUsageSeconds') ? (d.get('totalUsageSeconds') as num).toDouble() : 0.0) / 3600.0).toList();
      weeklyGuiltIndices = recentDocs.map((d) => (d.data().containsKey('guiltIndex') ? (d.get('guiltIndex') as num).toDouble() : 0.0)).toList();
      
      // Calculate Per-App Averages
      Map<String, List<double>> appDataPoints = {};
      for (var doc in recentDocs) {
        final data = doc.data();
        if (data.containsKey('appsUsed')) {
          Map<String, dynamic> apps = data['appsUsed'] as Map<String, dynamic>;
          apps.forEach((pkg, time) {
            appDataPoints.putIfAbsent(pkg, () => []).add((time as num).toDouble());
          });
        }
      }
      appWeeklyAverages = appDataPoints.map((pkg, points) => MapEntry(pkg, points.reduce((a, b) => a + b) / points.length));

      // Calculate Weekly Averages for Slider 4
      if (weeklyUsageHours.isNotEmpty) {
        weeklyAvgUsage = weeklyUsageHours.reduce((a, b) => a + b) / weeklyUsageHours.length;
      }
      if (weeklyGuiltIndices.isNotEmpty) {
        weeklyAvgGuilt = weeklyGuiltIndices.reduce((a, b) => a + b) / weeklyGuiltIndices.length;
      }

    } catch (e) {
      print("Weekly Trend Error: $e");
    }
  }

  Map<String, int> getSuggestedLimit(String packageName) {
    double avgSec = appWeeklyAverages[packageName] ?? 3600.0; // Default 1hr if no data
    double avgHours = avgSec / 3600.0;
    final socialKeywords = ['instagram', 'facebook', 'tiktok', 'snapchat', 'twitter', 'youtube', 'game', 'chess', 'mafia', 'netflix', 'prime'];
    
    // Logic: 
    // 1. Social/Games usually 30% reduction.
    // 2. But if Usage > 3 hours, we reduce little by little (15%) to avoid shock.
    // 3. Others 10%.
    double reductionFactor = 0.10; // Default 10%
    if (socialKeywords.any((k) => packageName.toLowerCase().contains(k))) {
      reductionFactor = (avgHours > 3.0) ? 0.15 : 0.30;
    }

    int suggestedSec = (avgSec * (1 - reductionFactor)).round();
    if (suggestedSec < 900) suggestedSec = 900; // Min 15 mins
    
    return {
      'h': suggestedSec ~/ 3600,
      'm': (suggestedSec % 3600) ~/ 60,
      's': suggestedSec % 60,
    };
  }

  Future<void> _allocateDailyTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAllocated = prefs.getString('lastTaskAllocationDate') ?? '';
      final todayStr = DateTime.now().toString().split(' ').first;
      if (lastAllocated == todayStr) {
        dailyTasks = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('dailyTasksJson') ?? '[]'));
        return;
      }
      final poolQuery = await FirebaseFirestore.instance.collection('tasksPool').get();
      if (poolQuery.docs.isEmpty) return;
      final allTasks = poolQuery.docs.map((doc) => doc.data()).toList();
      allTasks.shuffle();
      dailyTasks = allTasks.take(3).map((t) => {...t, 'completed': false}).toList();
      await prefs.setString('dailyTasksJson', jsonEncode(dailyTasks));
      await prefs.setString('lastTaskAllocationDate', todayStr);
    } catch (e) { }
  }

  Future<void> _loadNativeData() async {
    try {
      final totalHours = await _channel.invokeMethod<double>('getForegroundScreenTime') ?? 0.0;
      totalScreenTimeHours = totalHours * 60.0; 
      unlockCount = await _channel.invokeMethod('getUnlockCount') ?? 0;
      final nightStats = await _channel.invokeMapMethod<String, dynamic>('getNightUsageStats');
      if (nightStats != null) {
        nightAppsOpened = nightStats['appsOpened'] as int? ?? 0;
        isNightPassive = nightStats['isPassive'] as bool? ?? true;
      }
      final topAppsRaw = await _channel.invokeMapMethod<dynamic, dynamic>('getTopAppUsage');
      if (topAppsRaw != null) topAppUsage = topAppsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble() * 60.0));
    } catch (e) { }
  }

  Future<void> _loadStreaksAndTasks() async {
    final prefs = await SharedPreferences.getInstance();
    currentStreak = prefs.getInt('currentStreak') ?? 3;
    maxStreak = prefs.getInt('maxStreak') ?? 12;
    totalTasksCompleted = prefs.getInt('totalTasksCompleted') ?? 45;
    glowDays = prefs.getInt('glowDays') ?? 8;
    usageLimitHours = prefs.getInt('usageLimitHours') ?? 5;
  }

  void _calculateGuiltIndex() {
    double guiltHours = 0.0;
    final guiltKeywords = ['instagram', 'tiktok', 'youtube', 'facebook', 'snapchat', 'game', 'netflix', 'prime'];
    for (var entry in topAppUsage.entries) {
      if (guiltKeywords.any((k) => entry.key.toLowerCase().contains(k))) guiltHours += entry.value;
    }
    guiltIndex = (totalScreenTimeHours > 0) ? (guiltHours / totalScreenTimeHours) * 100.0 : 0.0;
  }

  void _calculatePenaltyScore() {
    violations.clear();
    penaltyBreakdown.clear();
    double score = 0.0;
    double goalMinutes = usageLimitHours * 60.0;
    
    if (goalMinutes > 0 && totalScreenTimeHours > goalMinutes) {
      double p = ((totalScreenTimeHours - goalMinutes) / goalMinutes * 20).clamp(0.0, 40.0);
      score += p; penaltyBreakdown['Over Usage'] = p;
      violations.add("Usage Goal Exceeded");
    }
    if (guiltIndex > 40) { 
      double p = (guiltIndex / 100) * 30;
      score += p; penaltyBreakdown['Wasteful Binging'] = p;
      violations.add("Wasteful App Binge"); 
    }
    if (nightAppsOpened > 0) { 
      double p = (nightAppsOpened * 4).toDouble().clamp(0.0, 20.0);
      score += p; penaltyBreakdown['Night Usage'] = p;
      violations.add("Night Activity (11PM-6AM)"); 
    }
    if (unlockCount > 40) { 
      double p = ((unlockCount - 40) / 5).toDouble().clamp(0.0, 10.0);
      score += p; penaltyBreakdown['Pickups'] = p;
      violations.add("Excessive Pickups"); 
    }
    penaltyScore = score.clamp(0.0, 100.0);
  }

  void _categorizeApps() {
    categoryBreakdown = {'Social Media': 0.0, 'Games': 0.0, 'Video/Entertainment': 0.0, 'Messages': 0.0, 'Surfing': 0.0, 'Tools & Other': 0.0};
    final keywords = {'Social Media': ['instagram', 'facebook', 'snapchat', 'tiktok', 'twitter', 'x'], 'Games': ['game', 'clash', 'pubg', 'candy', 'chess'], 'Video/Entertainment': ['youtube', 'netflix', 'prime', 'video', 'player'], 'Messages': ['whatsapp', 'telegram', 'messenger', 'messages', 'discord'], 'Surfing': ['chrome', 'browser', 'google', 'search', 'safari']};
    topAppUsage.forEach((name, time) {
      bool categorized = false;
      keywords.forEach((cat, keys) { if (!categorized && keys.any((k) => name.toLowerCase().contains(k))) { categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0) + time; categorized = true; }});
      if (!categorized) categoryBreakdown['Tools & Other'] = (categoryBreakdown['Tools & Other'] ?? 0) + time;
    });
  }

  Future<void> fetchGroqInference() async {
    const endpoint = 'https://api.groq.com/openai/v1/chat/completions';
    try {
      final streakResp = await http.post(Uri.parse(endpoint), headers: {'Authorization': 'Bearer $_groqKey', 'Content-Type': 'application/json'}, body: jsonEncode({"model": "llama3-8b-8192", "messages": [{"role": "system", "content": "You are Luminance, coach."}, {"role": "user", "content": "Completed $totalTasksCompleted tasks, streak is $currentStreak. Insight?"}]}));
      if (streakResp.statusCode == 200) aiInference = jsonDecode(streakResp.body)['choices'][0]['message']['content'].trim();
    } catch (e) { }
  }

  Future<void> _checkAppBlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = jsonDecode(prefs.getString('app_block_settings') ?? '{}') as Map<String, dynamic>;
      final blocked = <String>[];
      settings.forEach((pkg, cfg) { if (cfg['enabled'] == true) blocked.add(pkg); });
      await prefs.setString('blocked_packages_json', jsonEncode(blocked));
    } catch (e) { }
  }

  Future<void> _syncToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirestoreService().updateUserData(age: 20, name: "Cloud Kid", email: user.email ?? "", phone: "4582365785", goal: "Reduce Addiction", currentStreak: currentStreak, maxStreak: maxStreak, glowStreaks: glowDays, appLimits: {}, completedTasks: [], dailyTasks: dailyTasks.map((t) => t['title'] as String).toList(), preferences: ["Focus"]);
      await FirestoreService().saveUsageHistory(totalUsageSeconds: totalScreenTimeHours * 60, appsUsed: topAppUsage, addictionScore: penaltyScore);
    } catch (e) { }
  }
}
