import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// High-importance foreground notification service for driver job alerts.
class NotificationService {
  static const String driverJobAlertsChannelId = 'driver_job_alerts';
  static const String driverJobAlertsChannelName = 'Driver Job Alerts';
  static const String driverJobAlertsChannelDesc =
      'Loud foreground alerts when a new shuttle request is received.';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: initSettings);
    _initialized = true;
  }

  /// Shows a high-priority notification. Used whenever a new pending request
  /// enters the driver job stream.
  Future<void> showDriverJobAlert({
    required String title,
    required String body,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      driverJobAlertsChannelId,
      driverJobAlertsChannelName,
      channelDescription: driverJobAlertsChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert'), // Optional custom sound
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.transport,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
