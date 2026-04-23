import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // 1. usersData (Table 1)
  Future<void> updateUserData({
    required int age,
    required Map<String, dynamic> appLimits,
    required List<String> completedTasks,
    required int currentStreak,
    required List<String> dailyTasks,
    required String email,
    required int glowStreaks,
    required String goal,
    required int maxStreak,
    required String name,
    required String phone,
    required List<String> preferences,
  }) async {
    if (userId == null) return;

    await _db.collection('usersData').doc(userId).set({
      'age': age,
      'appLimits': appLimits,
      'completedTasks': completedTasks,
      'currentStreak': currentStreak,
      'dailyTasks': dailyTasks,
      'email': email,
      'glowStreaks': glowStreaks,
      'goal': goal,
      'lastActionDate': FieldValue.serverTimestamp(),
      'maxStreak': maxStreak,
      'name': name,
      'phone': phone,
      'preferences': preferences,
    }, SetOptions(merge: true));
  }

  // 2. usageHistory (Table 2)
  Future<void> saveUsageHistory({
    required double totalUsageSeconds,
    required Map<String, double> appsUsed,
    required double addictionScore,
  }) async {
    if (userId == null) return;
    
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final docId = "${userId}_$todayStr";

    await _db.collection('usageHistory').doc(docId).set({
      'userId': userId,
      'date': FieldValue.serverTimestamp(),
      'totalUsageSeconds': totalUsageSeconds,
      'appsUsed': appsUsed,
      'addictionScore': addictionScore,
    }, SetOptions(merge: true));
  }

  // 3. streaks (Table 3) - Now includes tasks done
  Future<void> saveStreakRecord({
    required int currentStreak,
    required int glowStreaks,
    required int tasksDone,
    required double screenTimeHours,
  }) async {
    if (userId == null) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final docId = "${userId}_$todayStr";

    await _db.collection('streaks').doc(docId).set({
      'userId': userId,
      'date': FieldValue.serverTimestamp(),
      'currentStreak': currentStreak,
      'glowStreaks': glowStreaks,
      'tasksDone': tasksDone,
      'screenTimeHours': screenTimeHours,
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot?> getUserData() async {
    if (userId == null) return null;
    return await _db.collection('usersData').doc(userId).get();
  }
}
