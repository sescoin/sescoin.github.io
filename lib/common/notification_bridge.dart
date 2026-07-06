import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../services/system_notifications/system_notifications.dart';

/// Relaie les notifications in-app (temps réel Supabase) vers les
/// notifications **système** : barre de notification sur Android,
/// notifications du navigateur sur le web (onglet en arrière-plan).
///
/// Monté une seule fois dans le shell principal, après connexion.
/// Limite assumée : sans serveur de push (FCM), aucune notification ne peut
/// arriver quand l'application est complètement fermée.
class NotificationBridge extends ConsumerStatefulWidget {
  const NotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends ConsumerState<NotificationBridge>
    with WidgetsBindingObserver {
  /// Les notifications antérieures au lancement ne sont pas rejouées.
  final DateTime _bootTime = DateTime.now();
  final Set<String> _shownIds = {};

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initSystemNotifications();
      await requestSystemNotificationPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  void _relay(List<AppNotification> notifications) {
    // Pas de notification système quand l'app est au premier plan : l'info est
    // déjà visible dans l'app. On ne notifie qu'en arrière-plan.
    final inForeground = _lifecycle == AppLifecycleState.resumed;
    for (final notification in notifications) {
      if (notification.isRead) continue;
      if (!notification.createdAt.isAfter(_bootTime)) continue;
      if (!_shownIds.add(notification.id)) continue;
      if (inForeground) continue;
      if (!shouldShowSystemNotification) continue;
      showSystemNotification(
        title: notification.title,
        body: notification.body,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AppNotification>>>(
      notificationsProvider,
      (previous, next) {
        final notifications = next.valueOrNull;
        if (notifications != null) _relay(notifications);
      },
    );
    return widget.child;
  }
}
