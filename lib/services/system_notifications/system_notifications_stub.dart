/// Implémentation par défaut : aucune notification système disponible.
Future<void> initSystemNotifications() async {}

Future<bool> requestSystemNotificationPermission() async => false;

bool get shouldShowSystemNotification => false;

Future<void> showSystemNotification({
  required String title,
  required String body,
}) async {}
