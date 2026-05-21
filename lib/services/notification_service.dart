import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/app_notification.dart';

class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  /// Notifications d'un utilisateur (les plus récentes en premier)
  Future<List<AppNotification>> getNotifications({
    required String userId,
    int page = 0,
    int pageSize = 30,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final data = await _client
        .from(AppConstants.tableNotifications)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// Notifications non lues uniquement
  Future<List<AppNotification>> getUnreadNotifications(String userId) async {
    final data = await _client
        .from(AppConstants.tableNotifications)
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .order('created_at', ascending: false);

    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// Nombre de notifications non lues (pour le badge)
  Future<int> getUnreadCount(String userId) async {
    final data = await _client
        .from(AppConstants.tableNotifications)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (data as List).length;
  }

  // ─── Marquage ─────────────────────────────────────────────────────────────────

  /// Marque une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from(AppConstants.tableNotifications)
        .update({'is_read': true}).eq('id', notificationId);
  }

  /// Marque toutes les notifications d'un utilisateur comme lues
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from(AppConstants.tableNotifications)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ─── Suppression ─────────────────────────────────────────────────────────────

  /// Supprime une notification
  Future<void> deleteNotification(String notificationId) async {
    await _client
        .from(AppConstants.tableNotifications)
        .delete()
        .eq('id', notificationId);
  }

  /// Supprime toutes les notifications lues d'un utilisateur
  Future<void> clearReadNotifications(String userId) async {
    await _client
        .from(AppConstants.tableNotifications)
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true);
  }

  // ─── Envoi (admin / système) ─────────────────────────────────────────────────

  /// Envoie une notification à un utilisateur spécifique
  Future<AppNotification> sendToUser({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final response = await _client
        .from(AppConstants.tableNotifications)
        .insert({
          'user_id': userId,
          'type': _typeToDb(type),
          'title': title,
          'body': body,
          'data': data,
          'is_read': false,
        })
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  /// Envoie une notification à tous les utilisateurs actifs (admin)
  Future<void> broadcastToAll({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _client.rpc('broadcast_notification', params: {
      'p_type': _typeToDb(type),
      'p_title': title,
      'p_body': body,
      'p_data': data,
    });
  }

  // ─── FCM Token ───────────────────────────────────────────────────────────────

  /// Met à jour le token FCM d'un utilisateur (pour les push notifications)
  Future<void> updateFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    await _client
        .from(AppConstants.tableProfiles)
        .update({'fcm_token': fcmToken}).eq('id', userId);
  }

  /// Supprime le token FCM à la déconnexion
  Future<void> clearFcmToken(String userId) async {
    await _client
        .from(AppConstants.tableProfiles)
        .update({'fcm_token': null}).eq('id', userId);
  }

  // ─── Realtime ────────────────────────────────────────────────────────────────

  /// Stream des notifications d'un utilisateur (nouvelles en temps réel)
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _client
        .from(AppConstants.tableNotifications)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => AppNotification.fromJson(r)).toList());
  }

  /// Stream du nombre de non-lus (pour le badge de l'onglet)
  Stream<int> watchUnreadCount(String userId) {
    return _client
        .from(AppConstants.tableNotifications)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }

  // ─── Helpers privés ──────────────────────────────────────────────────────────

  String _typeToDb(NotificationType type) {
    switch (type) {
      case NotificationType.transactionReceived:
        return 'transaction_received';
      case NotificationType.transactionSent:
        return 'transaction_sent';
      case NotificationType.transactionConfirmationRequired:
        return 'transaction_confirmation_required';
      case NotificationType.auctionOutbid:
        return 'auction_outbid';
      case NotificationType.auctionWon:
        return 'auction_won';
      case NotificationType.auctionEnded:
        return 'auction_ended';
      case NotificationType.loanRequested:
        return 'loan_requested';
      case NotificationType.loanAccepted:
        return 'loan_accepted';
      case NotificationType.loanRejected:
        return 'loan_rejected';
      case NotificationType.loanRepaid:
        return 'loan_repaid';
      case NotificationType.loanOverdue:
        return 'loan_overdue';
      case NotificationType.marketplacePurchase:
        return 'marketplace_purchase';
      case NotificationType.accountApproved:
        return 'account_approved';
      case NotificationType.accountRejected:
        return 'account_rejected';
      case NotificationType.adminTax:
        return 'admin_tax';
      case NotificationType.adminReward:
        return 'admin_reward';
      case NotificationType.system:
        return 'system';
    }
  }
}
