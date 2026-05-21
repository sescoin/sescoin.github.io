import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'service_providers.dart';

// ── Transactions récentes (dashboard) ─────────────────────────────────────────
final recentTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(transactionServiceProvider).getRecentTransactions(
        userId: userId,
        limit: 5,
      );
});

// ── Stream temps réel (dashboard live) ───────────────────────────────────────
final recentTransactionsStreamProvider =
    StreamProvider<List<Transaction>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(transactionServiceProvider).watchRecentTransactions(userId);
});

// ── Historique paginé (wallet) ────────────────────────────────────────────────

class WalletState {
  final List<Transaction> items;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? error;

  const WalletState({
    this.items = const [],
    this.currentPage = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  WalletState copyWith({
    List<Transaction>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return WalletState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(const WalletState()) {
    loadInitial();
  }

  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> loadInitial() async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(
      isRefreshing: true,
      clearError: true,
      items: [],
      currentPage: 0,
      hasMore: true,
    );

    try {
      final list = await _ref.read(transactionServiceProvider).getTransactions(
            userId: userId,
            page: 0,
          );
      state = state.copyWith(
        items: list,
        currentPage: 1,
        hasMore: list.length == AppConstants.transactionHistoryPageSize,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final list = await _ref.read(transactionServiceProvider).getTransactions(
            userId: userId,
            page: state.currentPage,
          );
      state = state.copyWith(
        items: [...state.items, ...list],
        currentPage: state.currentPage + 1,
        hasMore: list.length == AppConstants.transactionHistoryPageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadInitial();
    // Rafraîchit aussi le solde
    await _ref.read(currentProfileProvider.notifier).refresh();
  }
}

// ── Transfert manuel ──────────────────────────────────────────────────────────

class TransferState {
  final bool isLoading;
  final String? error;
  final Transaction? lastTransaction;

  const TransferState({
    this.isLoading = false,
    this.error,
    this.lastTransaction,
  });

  TransferState copyWith({
    bool? isLoading,
    String? error,
    Transaction? lastTransaction,
    bool clearError = false,
  }) {
    return TransferState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastTransaction: lastTransaction ?? this.lastTransaction,
    );
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier(ref);
});

class TransferNotifier extends StateNotifier<TransferState> {
  final Ref _ref;

  TransferNotifier(this._ref) : super(const TransferState());

  Future<Transaction> transferByUsername({
    required String toUsername,
    required double amount,
    String? description,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tx = await _ref.read(transactionServiceProvider).transferByUsername(
            fromUserId: userId,
            toUsername: toUsername,
            amount: amount,
            description: description,
          );
      state = state.copyWith(isLoading: false, lastTransaction: tx);
      // Rafraîchit le solde et l'historique
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      return tx;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  void reset() => state = const TransferState();
}
