import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream.empty();
  }
  return ref.watch(notificationServiceProvider).watchNotifications(userId);
});

final unreadCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const Stream.empty();
  }
  return ref.watch(notificationServiceProvider).watchUnreadCount(userId);
});

final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>(
  (ref) => NotificationActionsNotifier(ref),
);

class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  NotificationActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> markAsRead(String notificationId) async {
    try {
      await _ref.read(notificationServiceProvider).markAsRead(notificationId);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    try {
      await _ref.read(notificationServiceProvider).markAllAsRead(userId);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _ref
          .read(notificationServiceProvider)
          .deleteNotification(notificationId);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> clearRead() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    try {
      await _ref.read(notificationServiceProvider).clearReadNotifications(userId);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> clearAll() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    try {
      await _ref.read(notificationServiceProvider).clearAllNotifications(userId);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    try {
      await _ref.read(notificationServiceProvider).updateFcmToken(
            userId: userId,
            fcmToken: fcmToken,
          );
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
