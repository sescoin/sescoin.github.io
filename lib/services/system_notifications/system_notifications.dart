/// Pont vers les notifications **système** (barre de notification Android,
/// notifications du navigateur sur le web).
///
/// L'implémentation est choisie à la compilation selon la plateforme :
/// - `system_notifications_io.dart`  : Android / iOS (flutter_local_notifications)
/// - `system_notifications_web.dart` : navigateur (API Notification)
///
/// API commune :
/// - `initSystemNotifications()`             : initialisation (idempotente)
/// - `requestSystemNotificationPermission()` : demande la permission
/// - `shouldShowSystemNotification`          : opportunité d'affichage
///   (sur web : uniquement quand l'onglet est en arrière-plan)
/// - `showSystemNotification(...)`           : affiche la notification
library;

export 'system_notifications_stub.dart'
    if (dart.library.io) 'system_notifications_io.dart'
    if (dart.library.js_interop) 'system_notifications_web.dart';
