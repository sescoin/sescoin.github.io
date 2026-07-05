import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Notifications navigateur via l'API Notification du web.
bool get _supported {
  try {
    return web.window.hasProperty('Notification'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Future<void> initSystemNotifications() async {}

Future<bool> requestSystemNotificationPermission() async {
  if (!_supported) return false;
  try {
    if (web.Notification.permission == 'granted') return true;
    if (web.Notification.permission == 'denied') return false;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

/// Sur le web, on ne notifie que si l'onglet est en arrière-plan :
/// quand la page est visible, l'interface suffit.
bool get shouldShowSystemNotification {
  if (!_supported) return false;
  try {
    return web.document.hidden && web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> showSystemNotification({
  required String title,
  required String body,
}) async {
  if (!_supported) return;
  try {
    if (web.Notification.permission != 'granted') return;
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
    );
  } catch (_) {
    // L'API peut être indisponible (permissions, contexte non sécurisé…) :
    // les notifications restent visibles dans l'app.
  }
}
