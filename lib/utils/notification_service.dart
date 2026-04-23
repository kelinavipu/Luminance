import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const List<String> _sarcasticQuotes = [
    "Oh, look who's still on their phone. How original.",
    "Your thumb must be exhausted from all that scrolling.",
    "Don't worry, the internet will still be there in 10 minutes.",
    "Is that app paying you? No? Then put it down.",
    "Touch some grass. Seriously. It's green and outside.",
    "Your screen time is higher than your grades/salary/hopes.",
    "Breaking news: The world outside hasn't changed since you last checked.",
    "Go blink. Your eyes are starting to look like raisins.",
  ];

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(initializationSettings);
  }

  static Future<void> showSarcasticNotification() async {
    final random = Random();
    final quote = _sarcasticQuotes[random.nextInt(_sarcasticQuotes.length)];

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'luminance_channel',
      'Luminance Alerts',
      channelDescription: 'Sarcastic digital wellbeing reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      0,
      'Still here?',
      quote,
      notificationDetails,
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await NotificationService.init();
    await NotificationService.showSarcasticNotification();
    return Future.value(true);
  });
}
