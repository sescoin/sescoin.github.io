import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/account_request.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  Future<Profile> getProfile(String userId) async {
    final data =
        await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
  }

  Future<Profile?> getProfileByUsername(String username) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('username', username)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Tous les profils actifs (pour leaderboard / portefeuilles publics)
  Future<List<Profile>> getAllProfiles() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('is_banned', false)
        .order('balance', ascending: false);
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  /// Classement public trié par solde
  Future<List<Profile>> getLeaderboard() async {
    final data = await _client
        .from('profiles')
        .select(
            'id, username, display_name, avatar_url, balance, role, is_banned, created_at, fcm_token')
        .eq('is_banned', false)
        .order('balance', ascending: false)
        .limit(50);
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  // ─── Mise à jour profil ──────────────────────────────────────────────────────

  Future<Profile> updateAvatar(String userId, String avatarUrl) async {
    final data = await _client
        .from('profiles')
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  Future<Profile> updateDisplayName(String userId, String displayName) async {
    final data = await _client
        .from('profiles')
        .update({
          'display_name': displayName,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  // ─── Demandes de compte (admin) ──────────────────────────────────────────────

  Future<List<AccountRequest>> getPendingRequests() async {
    final data = await _client
        .from('account_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return (data as List).map((e) => AccountRequest.fromJson(e)).toList();
  }

  Future<List<AccountRequest>> getAllRequests() async {
    final data = await _client
        .from('account_requests')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => AccountRequest.fromJson(e)).toList();
  }

  /// Approuve une demande → crée le compte Supabase Auth + profil via RPC
  Future<void> approveRequest({
    required String requestId,
    required double initialBalance,
  }) async {
    await _client.rpc('approve_account_request', params: {
      'p_request_id': requestId,
      'p_initial_balance': initialBalance,
    });
  }

  /// Modifie la classe choisie sur une demande en attente (admin)
  Future<void> setAccountRequestClass(String requestId, String? classId) async {
    await _client.rpc('set_account_request_class', params: {
      'p_request_id': requestId,
      'p_class_id': classId,
    });
  }

  /// Refuse une demande
  Future<void> rejectRequest({
    required String requestId,
    String? reason,
  }) async {
    await _client.from('account_requests').update({
      'status': 'refused',
      'refusal_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId).eq('status', 'pending');
  }

  /// Demande un changement de photo de profil (nécessite approbation admin)
  Future<void> requestAvatarChange(String userId, String pendingAvatarUrl) async {
    await _client.rpc('request_avatar_change', params: {
      'p_user_id': userId,
      'p_pending_avatar_url': pendingAvatarUrl,
    });
  }

  /// Admin : approuve la photo de profil en attente
  Future<void> approveAvatarChange(String userId) async {
    await _client.rpc('approve_avatar_change', params: {'p_user_id': userId});
  }

  /// Admin : refuse la photo de profil en attente
  Future<void> rejectAvatarChange(String userId) async {
    await _client.rpc('reject_avatar_change', params: {'p_user_id': userId});
  }

  // ─── Actions admin ───────────────────────────────────────────────────────────

  /// Crédite ou débite manuellement un compte
  Future<void> adminAdjustBalance({
    required String userId,
    required double amount, // positif = crédit, négatif = débit
    required String reason,
  }) async {
    await _client.rpc('admin_adjust_balance', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_reason': reason,
    });
  }

  /// Taxe tous les comptes d'un pourcentage
  Future<void> taxAll({
    required double percent,
    required String reason,
  }) async {
    await _client.rpc('admin_tax_all', params: {
      'p_percent': percent,
      'p_reason': reason,
    });
  }

  /// Distribue une récompense à tous les comptes actifs
  Future<void> rewardAll({
    required double amount,
    required String reason,
  }) async {
    await _client.rpc('admin_reward_all', params: {
      'p_amount': amount,
      'p_reason': reason,
    });
  }

  /// Bannit un compte (RPC : l'UPDATE direct était bloqué par RLS).
  /// La notification à l'utilisateur est créée par la fonction SQL.
  Future<void> banUser(String userId, {String? reason}) async {
    await _client.rpc('admin_ban_user', params: {
      'p_user_id': userId,
      if (reason != null && reason.trim().isNotEmpty)
        'p_reason': reason.trim(),
    });
  }

  /// Débannit un compte (RPC, notification incluse côté SQL).
  Future<void> unbanUser(String userId) async {
    await _client.rpc('admin_unban_user', params: {'p_user_id': userId});
  }

  /// Supprime un compte définitivement
  Future<void> deleteUser(String userId) async {
    await _client.rpc('admin_delete_user', params: {'p_user_id': userId});
  }

  /// Définit sa propre citation, ou l'efface si [quote] est vide.
  ///
  /// Passe par une RPC : longueur, caractères invisibles et langage sont
  /// vérifiés côté serveur, un client pouvant toujours écrire en base.
  Future<void> setQuote(String? quote) async {
    await _client.rpc('set_profile_quote', params: {'p_quote': quote});
  }

  /// Supprime la citation d'un compte (RPC réservée à l'administrateur).
  Future<void> clearQuote(String userId) async {
    await _client.rpc('admin_clear_quote', params: {'p_user_id': userId});
  }

  /// Redéfinit le mot de passe d'un compte (RPC réservée à l'administrateur).
  Future<void> resetPassword(String userId, String newPassword) async {
    await _client.rpc(
      'admin_reset_password',
      params: {'p_user_id': userId, 'p_new_password': newPassword},
    );
  }

  // ─── Realtime ────────────────────────────────────────────────────────────────

  /// Stream des demandes en attente (temps réel pour le panel admin)
  Stream<List<AccountRequest>> watchPendingRequests() {
    return _client
        .from('account_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) => rows
            .where((r) => r['status'] == 'pending')
            .map((e) => AccountRequest.fromJson(e))
            .toList());
  }

  /// Stream du profil connecté (solde mis à jour en temps réel)
  Stream<Profile> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => Profile.fromJson(rows.first));
  }

  /// Stream du leaderboard en temps réel
  Stream<List<Profile>> watchLeaderboard() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('balance', ascending: false)
        .map((rows) => rows
            .where((r) => r['is_banned'] == false)
            .map((r) => Profile.fromJson(r))
            .toList());
  }

  Stream<List<Profile>> watchAllProfiles() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('balance', ascending: false)
        .map((rows) => rows.map((row) => Profile.fromJson(row)).toList());
  }
}
