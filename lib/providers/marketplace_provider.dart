import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace_item.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'service_providers.dart';
import 'wallet_provider.dart';

// ── Items disponibles (realtime) ──────────────────────────────────────────────
final marketplaceItemsProvider = StreamProvider<List<MarketplaceItem>>((ref) {
  return ref.watch(marketplaceServiceProvider).watchAvailableItems();
});

// ── Historique d'achats ───────────────────────────────────────────────────────
final purchaseHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(marketplaceServiceProvider).getPurchaseHistory(userId);
});

// ── Achat ─────────────────────────────────────────────────────────────────────

class PurchaseState {
  final bool isLoading;
  final String? error;
  final Transaction? lastTransaction;
  final MarketplaceItem? lastItem;

  const PurchaseState({
    this.isLoading = false,
    this.error,
    this.lastTransaction,
    this.lastItem,
  });

  PurchaseState copyWith({
    bool? isLoading,
    String? error,
    Transaction? lastTransaction,
    MarketplaceItem? lastItem,
    bool clearError = false,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastTransaction: lastTransaction ?? this.lastTransaction,
      lastItem: lastItem ?? this.lastItem,
    );
  }
}

final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  return PurchaseNotifier(ref);
});

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final Ref _ref;

  PurchaseNotifier(this._ref) : super(const PurchaseState());

  Future<void> purchase({
    required String itemId,
    int quantity = 1,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _ref.read(marketplaceServiceProvider).purchaseItem(
            buyerId: userId,
            itemId: itemId,
            quantity: quantity,
          );
      state = state.copyWith(
        isLoading: false,
        lastTransaction: result.transaction,
        lastItem: result.item,
      );
      // Rafraîchit solde + historique
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      _ref.invalidateSelf(); // refresh purchaseHistory
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  void reset() => state = const PurchaseState();
}
