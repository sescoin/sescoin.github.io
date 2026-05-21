import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auction.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

// ── Liste enchères actives (realtime) ─────────────────────────────────────────
final activeAuctionsProvider = StreamProvider<List<Auction>>((ref) {
  return ref.watch(auctionServiceProvider).watchActiveAuctions();
});

// ── Enchère individuelle (realtime) ───────────────────────────────────────────
final auctionStreamProvider =
    StreamProvider.family<Auction, String>((ref, auctionId) {
  return ref.watch(auctionServiceProvider).watchAuction(auctionId);
});

// ── Offres d'une enchère (realtime) ───────────────────────────────────────────
final auctionBidsProvider =
    StreamProvider.family<List<AuctionBid>, String>((ref, auctionId) {
  return ref.watch(auctionServiceProvider).watchBids(auctionId);
});

// ── Enchères de l'utilisateur ─────────────────────────────────────────────────
final userAuctionsProvider = FutureProvider<List<Auction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(auctionServiceProvider).getUserAuctions(userId);
});

// ── Placer une enchère ────────────────────────────────────────────────────────

class BidState {
  final bool isLoading;
  final String? error;
  final Auction? updatedAuction;

  const BidState({
    this.isLoading = false,
    this.error,
    this.updatedAuction,
  });

  BidState copyWith({
    bool? isLoading,
    String? error,
    Auction? updatedAuction,
    bool clearError = false,
  }) {
    return BidState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      updatedAuction: updatedAuction ?? this.updatedAuction,
    );
  }
}

final bidProvider = StateNotifierProvider<BidNotifier, BidState>((ref) {
  return BidNotifier(ref);
});

class BidNotifier extends StateNotifier<BidState> {
  final Ref _ref;

  BidNotifier(this._ref) : super(const BidState());

  Future<void> placeBid({
    required String auctionId,
    required double amount,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _ref.read(auctionServiceProvider).placeBid(
            bidderId: userId,
            auctionId: auctionId,
            amount: amount,
          );
      state = state.copyWith(isLoading: false, updatedAuction: updated);
      // Rafraîchit le solde (la mise est réservée)
      await _ref.read(currentProfileProvider.notifier).refresh();
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  void reset() => state = const BidState();
}
