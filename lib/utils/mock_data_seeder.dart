import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class MockDataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> seedTasksPool() async {
    final tasks = [
      {'id': 'm1', 'title': 'Cloud Watching', 'category': 'Mindfulness', 'points': 10},
      {'id': 'm2', 'title': '3 Unique Sounds', 'category': 'Mindfulness', 'points': 5},
      {'id': 'm3', 'title': 'Deep Breathing (5m)', 'category': 'Mindfulness', 'points': 15},
      {'id': 'p1', 'title': 'Unsubscribe from 5 Emails', 'category': 'Productivity', 'points': 20},
      {'id': 'p2', 'title': 'Clean Your Desk', 'category': 'Productivity', 'points': 25},
      {'id': 'r1', 'title': 'Listen to 432Hz Music', 'category': 'Relaxation', 'points': 10},
      {'id': 'ph1', 'title': '10 Jumping Jacks', 'category': 'Physical', 'points': 10},
    ];
    final batch = _firestore.batch();
    for (var task in tasks) {
      batch.set(_firestore.collection('tasksPool').doc(task['id'] as String), task);
    }
    await batch.commit();
  }

  static Future<void> seedUsageHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final batch = _firestore.batch();

    for (int i = 0; i < 10; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      final random = Random();
      double randomFactor = 0.4 + random.nextDouble() * 1.2;
      bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      
      final appsUsed = {
        'com.android.chrome': (2500 * randomFactor).roundToDouble(),
        'com.google.android.youtube': (isWeekend ? 9000 : 1200) * randomFactor,
        'com.instagram': (isWeekend ? 7000 : 2500) * randomFactor,
        'com.netflix.mediaclient': (isWeekend ? 5000 : 0) * randomFactor,
      };

      final totalUsage = appsUsed.values.reduce((a, b) => a + b);
      // Generate very distinct guilt values for visualization
      final guiltIndex = (isWeekend ? 65.0 : 25.0) + (random.nextDouble() * 30.0);

      batch.set(_firestore.collection('usageHistory').doc("${user.uid}_$dateStr"), {
        'userId': user.uid,
        'date': dateStr,
        'timestamp': Timestamp.fromDate(date),
        'totalUsageSeconds': totalUsage,
        'appsUsed': appsUsed,
        'penaltyScore': (totalUsage / 15000 * 100).clamp(10, 100),
        'guiltIndex': guiltIndex.clamp(0.0, 100.0), 
        'unlockCount': (30 + random.nextInt(60)),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    print("Expanded 10-Day History Seeded Successfully!");
  }
}
