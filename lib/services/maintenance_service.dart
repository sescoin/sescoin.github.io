import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/maintenance_status.dart';

/// Accès aux fonctions de maintenance (voir la migration 20261022).
class MaintenanceService {
  MaintenanceService(this._client);

  final SupabaseClient _client;

  /// Situation de la session courante : mode en cours, blocage éventuel.
  Future<MaintenanceStatus> fetchStatus() async {
    final data = await _client.rpc('maintenance_status');
    if (data is! Map<String, dynamic>) return MaintenanceStatus.none;
    return MaintenanceStatus.fromJson(data);
  }

  /// Mode publié, à chaque changement (temps réel).
  Stream<MaintenanceMode> watchMode() {
    return _client
        .from('maintenance_state')
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows.isEmpty
              ? MaintenanceMode.off
              : MaintenanceMode.fromDb(rows.first['mode'] as String?),
        );
  }

  /// Vérifie un mot de passe de maintenance pour le compte [username].
  ///
  /// Renvoie `null` si ce n'est pas un mot de passe de maintenance de ce
  /// compte, ou si la base n'est pas encore équipée.
  Future<MaintenanceAccess?> requestAccess(
    String username,
    String password,
  ) async {
    try {
      final data = await _client.rpc(
        'maintenance_request_access',
        params: {'p_username': username, 'p_password': password},
      );
      if (data is! Map<String, dynamic>) return null;
      return MaintenanceAccess.fromJson(data);
    } on PostgrestException catch (e) {
      // Seul le blocage après trop d'essais remonte : il expliquerait sinon
      // le refus d'un mot de passe pourtant juste.
      if (e.message.startsWith('Trop de tentatives')) rethrow;
      return null;
    }
  }

  /// Abandonne une connexion de maintenance : le vrai mot de passe revient.
  Future<void> cancel(String ticket) async {
    try {
      await _client.rpc('maintenance_cancel', params: {'p_ticket': ticket});
    } catch (_) {
      // Le secret est de toute façon abandonné par la base au bout de deux
      // minutes.
    }
  }

  /// Enregistre la session courante comme session de maintenance.
  Future<bool> activate(String ticket) async {
    final data = await _client.rpc(
      'maintenance_activate',
      params: {'p_ticket': ticket},
    );
    return data is Map && data['ok'] == true;
  }

  /// Termine la maintenance si la session courante l'avait ouverte.
  Future<void> end() async {
    if (_client.auth.currentSession == null) return;
    try {
      await _client.rpc('maintenance_end').timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sans réponse, la base constate d'elle-même la disparition de la
      // session à la déconnexion et ferme la maintenance.
    }
  }
}
