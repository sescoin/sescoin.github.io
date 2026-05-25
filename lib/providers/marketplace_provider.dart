import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace_item.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import 'service_providers.dart';
import 'wallet_provider.dart';

final marketplaceItemsProvider = StreamProvider<List<MarketplaceItem>>((ref) {
  return ref.watch(marketplaceServiceProvider).watchAvailableItems();
});

final purchaseHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return [];
  }
  return ref.watch(marketplaceServiceProvider).getPurchaseHistory(userId);
});

class PurchaseState {
  const PurchaseState({
    this.isLoading = false,
    this.error,
    this.lastTransaction,
    this.lastItem,
    this.loadingItemId,
  });

  final bool isLoading;
  final String? error;
  final Transaction? lastTransaction;
  final MarketplaceItem? lastItem;
  final String? loadingItemId;

  PurchaseState copyWith({
    bool? isLoading,
    String? error,
    Transaction? lastTransaction,
    MarketplaceItem? lastItem,
    String? loadingItemId,
    bool clearError = false,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastTransaction: lastTransaction ?? this.lastTransaction,
      lastItem: lastItem ?? this.lastItem,
      loadingItemId: loadingItemId ?? this.loadingItemId,
    );
  }
}

final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  return PurchaseNotifier(ref);
});

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  PurchaseNotifier(this._ref) : super(const PurchaseState());

  final Ref _ref;

  Future<void> purchase({
    required String itemId,
    int quantity = 1,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      throw Exception('Non connecté');
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      loadingItemId: itemId,
    );

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
        loadingItemId: itemId,
      );

      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      _ref.invalidate(purchaseHistoryProvider);
      _ref.invalidate(marketplaceItemsProvider);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadCountProvider);
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
        loadingItemId: itemId,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void reset() {
    state = const PurchaseState();
  }
}
