import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'luminance.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Daily Usage History
        await db.execute('''
          CREATE TABLE usage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT UNIQUE,
            total_usage_seconds REAL,
            apps_used_json TEXT
          )
        ''');

        // User Profile & Stats
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY DEFAULT 1,
            name TEXT,
            email TEXT,
            age INTEGER,
            goal TEXT,
            phone TEXT,
            current_streak INTEGER,
            max_streak INTEGER,
            glow_streaks INTEGER,
            preferences_json TEXT
          )
        ''');

        // Completed Tasks Tracking
        await db.execute('''
          CREATE TABLE completed_tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_name TEXT,
            date TEXT
          )
        ''');
      },
    );
  }

  // Save Today's Summary
  Future<void> saveDailyUsage({
    required double totalSeconds,
    required Map<String, double> appsUsed,
  }) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    await db.insert(
      'usage_history',
      {
        'date': today,
        'total_usage_seconds': totalSeconds,
        'apps_used_json': jsonEncode(appsUsed),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update User Profile
  Future<void> updateProfile({
    required String name,
    required String email,
    required int age,
    required String goal,
    required String phone,
    required int currentStreak,
    required int maxStreak,
    required int glowStreaks,
    required List<String> preferences,
  }) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {
        'id': 1,
        'name': name,
        'email': email,
        'age': age,
        'goal': goal,
        'phone': phone,
        'current_streak': currentStreak,
        'max_streak': maxStreak,
        'glow_streaks': glow_streaks,
        'preferences_json': jsonEncode(preferences),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Log Task Completion
  Future<void> logTask(String taskName) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    await db.insert('completed_tasks', {
      'task_name': taskName,
      'date': today,
    });
  }

  // Get Today's Stats
  Future<Map<String, dynamic>?> getTodayStats() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final results = await db.query('usage_history', where: 'date = ?', whereArgs: [today]);
    return results.isNotEmpty ? results.first : null;
  }
}
