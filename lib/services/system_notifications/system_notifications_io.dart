import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications système via flutter_local_notifications (Android / iOS).
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;
int _nextId = 0;

bool get _supported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

Future<void> initSystemNotifications() async {
  if (_initialized || !_supported) return;
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    ),
  );
  _initialized = true;
}

Future<bool> requestSystemNotificationPermission() async {
  if (!_supported) return false;
  await initSystemNotifications();
  if (Platform.isAndroid) {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }
  if (Platform.isIOS) {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }
  if (Platform.isMacOS) {
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    return await macos?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }
  return false;
}

/// Sur mobile, on notifie même app ouverte (bannière système discrète).
bool get shouldShowSystemNotification => _supported;

Future<void> showSystemNotification({
  required String title,
  required String body,
}) async {
  if (!_supported) return;
  await initSystemNotifications();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ses_coin_events',
      'Événements SES Coin',
      channelDescription:
          'Transactions, prêts, cadeaux, annonces et décisions de l\'administrateur',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );
  await _plugin.show(
    id: _nextId++,
    title: title,
    body: body,
    notificationDetails: details,
  );
}
