import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

// ── Profil courant en realtime ────────────────────────────────────────────────
// Se met à jour automatiquement quand le solde change dans Supabase
final currentProfileStreamProvider = StreamProvider<Profile>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(profileServiceProvider).watchProfile(userId);
});

// ── Leaderboard en realtime ───────────────────────────────────────────────────
final leaderboardStreamProvider = StreamProvider<List<Profile>>((ref) {
  return ref.watch(profileServiceProvider).watchLeaderboard();
});

// ── Profil public par username ────────────────────────────────────────────────
final publicProfileProvider =
    FutureProvider.family<Profile?, String>((ref, username) {
  return ref.watch(profileServiceProvider).getProfileByUsername(username);
});

// ── Tous les profils (admin) ──────────────────────────────────────────────────
final allProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(profileServiceProvider).getAllProfiles();
});

// ── Actions profil ────────────────────────────────────────────────────────────
final profileActionsProvider =
    StateNotifierProvider<ProfileActionsNotifier, AsyncValue<void>>(
  (ref) => ProfileActionsNotifier(ref),
);

class ProfileActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProfileActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateAvatar(String avatarUrl) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = const AsyncValue.loading();
    try {
      final updated = await _ref
          .read(profileServiceProvider)
          .updateAvatar(userId, avatarUrl);
      _ref.read(currentProfileProvider.notifier).updateLocal(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = const AsyncValue.loading();
    try {
      final updated = await _ref
          .read(profileServiceProvider)
          .updateDisplayName(userId, displayName);
      _ref.read(currentProfileProvider.notifier).updateLocal(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
