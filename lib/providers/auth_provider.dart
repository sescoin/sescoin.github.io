import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/account_request.dart';
import 'service_providers.dart';

// ── Stream brut Supabase Auth ─────────────────────────────────────────────────
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

// ── Profil courant ────────────────────────────────────────────────────────────
final currentProfileProvider =
    StateNotifierProvider<CurrentProfileNotifier, AsyncValue<Profile?>>(
  (ref) => CurrentProfileNotifier(ref),
);

class CurrentProfileNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final Ref _ref;
  StreamSubscription<Profile>? _profileSubscription;

  CurrentProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  // Charge le profil depuis Supabase au démarrage
  Future<void> _init() async {
    try {
      final authService = _ref.read(authServiceProvider);
      final profile = await authService.getCurrentProfile();

      if (profile == null && authService.currentUser != null) {
        // Session Supabase valide MAIS aucun profil dans la DB.
        // Cela arrive après un reset du schema : la session Auth persiste
        // mais la table profiles est vide. On déconnecte proprement pour
        // que le router redirige vers le login.
        await authService.signOut();
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(profile);
      _bindProfileStream(profile?.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Recharge depuis Supabase (après tx, ban, etc.)
  Future<void> refresh() async {
    try {
      final profile = await _ref.read(authServiceProvider).getCurrentProfile();
      state = AsyncValue.data(profile);
      _bindProfileStream(profile?.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Met à jour localement (optimistic update)
  void updateLocal(Profile updated) {
    state = AsyncValue.data(updated);
  }

  void _bindProfileStream(String? userId) {
    _profileSubscription?.cancel();
    if (userId == null) {
      _profileSubscription = null;
      return;
    }
    _profileSubscription =
        _ref.read(profileServiceProvider).watchProfile(userId).listen(
      (profile) {
        state = AsyncValue.data(profile);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  // ── Auth actions ────────────────────────────────────────────────────────────

  Future<Profile> signIn({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _ref.read(authServiceProvider).signIn(
            username: username,
            password: password,
          );
      state = AsyncValue.data(profile);
      _bindProfileStream(profile.id);
      return profile;
    } catch (e, st) {
      state = const AsyncValue.data(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> signOut() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    await _ref.read(authServiceProvider).signOut();
    state = const AsyncValue.data(null);
  }

  Future<AccountRequest> submitAccountRequest({
    required String firstName,
    required String lastName,
    required String password,
    required String avatarUrl,
    required String deviceId,
  }) async {
    return _ref.read(authServiceProvider).submitAccountRequest(
          firstName: firstName,
          lastName: lastName,
          password: password,
          avatarUrl: avatarUrl,
          deviceId: deviceId,
        );
  }

  Future<void> changePassword(String newPassword) async {
    await _ref.read(authServiceProvider).changePassword(newPassword);
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}

// ── Helpers dérivés ───────────────────────────────────────────────────────────

/// true si l'utilisateur est connecté
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentProfileProvider).value != null;
});

/// true si l'utilisateur est admin
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentProfileProvider).value?.isAdmin ?? false;
});

/// ID de l'utilisateur connecté (null si déconnecté)
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentProfileProvider).value?.id;
});
