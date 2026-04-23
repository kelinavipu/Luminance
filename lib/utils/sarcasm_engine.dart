import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class SarcasmEngine {
  static const _channel = MethodChannel('com.luminance/usage');
  static Timer? _timer;
  
  static String? _currentApp;
  static DateTime? _sessionStartTime;
  static final Map<String, DateTime> _lastRoastTime = {};

  static Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkForegroundApp();
    });
  }

  static Future<void> _checkForegroundApp() async {
    try {
      final String? foregroundApp = await _channel.invokeMethod('getForegroundApp');
      if (foregroundApp == null) return;

      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_notification_settings') ?? '{}';
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;

      if (!settings.containsKey(foregroundApp)) {
        _currentApp = null;
        _sessionStartTime = null;
        return;
      }

      final appSetting = settings[foregroundApp];
      if (appSetting['enabled'] != true) return;

      // Track session
      if (_currentApp != foregroundApp) {
        _currentApp = foregroundApp;
        _sessionStartTime = DateTime.now();
      }

      final int h = appSetting['h'] ?? 0;
      final int m = appSetting['m'] ?? 0;
      final int s = appSetting['s'] ?? 10;
      final totalSeconds = (h * 3600) + (m * 60) + s;

      final timeSpent = DateTime.now().difference(_sessionStartTime!).inSeconds;

      if (timeSpent >= totalSeconds) {
        // Only roast once per interval to avoid spam
        final lastRoast = _lastRoastTime[foregroundApp];
        if (lastRoast == null || DateTime.now().difference(lastRoast).inSeconds >= totalSeconds) {
          NotificationService.showSarcasticNotification();
          _lastRoastTime[foregroundApp] = DateTime.now();
        }
      }
    } catch (e) {
      print('SarcasmEngine Error: $e');
    }
  }

  static void stop() {
    _timer?.cancel();
  }
}
