import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auction_provider.dart';
import '../models/account_request.dart';
import '../models/loan.dart';
import '../models/loan_config.dart';
import 'auth_provider.dart';
import 'currency_provider.dart';
import 'loan_provider.dart';
import 'marketplace_provider.dart';
import 'profile_provider.dart';
import 'service_providers.dart';
import 'wallet_provider.dart';

// ── Demandes en attente ───────────────────────────────────────────────────────
final pendingRequestsProvider = StreamProvider<List<AccountRequest>>((ref) {
  return ref.watch(profileServiceProvider).watchPendingRequests();
});

// ── Toutes les demandes ───────────────────────────────────────────────────────
final allRequestsProvider = FutureProvider<List<AccountRequest>>((ref) {
  return ref.watch(profileServiceProvider).getAllRequests();
});

// ── Prêts en retard (admin) ───────────────────────────────────────────────────
final overdueLoansProvider = FutureProvider<List<Loan>>((ref) {
  return ref.watch(loanServiceProvider).getOverdueLoans();
});

// ── Actions admin ─────────────────────────────────────────────────────────────

class AdminActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AdminActionState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AdminActionState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AdminActionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearMessages ? null : (error ?? this.error),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

final adminActionsProvider =
    StateNotifierProvider<AdminActionsNotifier, AdminActionState>((ref) {
  return AdminActionsNotifier(ref);
});

class AdminActionsNotifier extends StateNotifier<AdminActionState> {
  final Ref _ref;

  AdminActionsNotifier(this._ref) : super(const AdminActionState());

  // ── Demandes de compte ──────────────────────────────────────────────────────

  Future<void> approveRequest({
    required String requestId,
    required double initialBalance,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).approveRequest(
            requestId: requestId,
            initialBalance: initialBalance,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Compte approuvé avec $initialBalance SC',
      );
      _ref.invalidate(pendingRequestsProvider);
      _ref.invalidate(allRequestsProvider);
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> rejectRequest({
    required String requestId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).rejectRequest(
            requestId: requestId,
            reason: reason,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Demande refusée',
      );
      _ref.invalidate(pendingRequestsProvider);
      _ref.invalidate(allRequestsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Gestion des comptes ─────────────────────────────────────────────────────

  Future<void> adjustBalance({
    required String userId,
    required double amount,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).adminAdjustBalance(
            userId: userId,
            amount: amount,
            reason: reason,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage:
            '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(2)} SC appliqué',
      );
      _ref.invalidate(allProfilesProvider);
      // Si c'est le compte de l'admin lui-même
      final currentId = _ref.read(currentUserIdProvider);
      if (currentId == userId) {
        await _ref.read(currentProfileProvider.notifier).refresh();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> banUser(String userId, {String? reason}) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).banUser(userId, reason: reason);
      state = state.copyWith(isLoading: false, successMessage: 'Compte banni');
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> unbanUser(String userId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).unbanUser(userId);
      state =
          state.copyWith(isLoading: false, successMessage: 'Compte débanni');
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).deleteUser(userId);
      state =
          state.copyWith(isLoading: false, successMessage: 'Compte supprimé');
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> approveAvatarChange(String userId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).approveAvatarChange(userId);
      state =
          state.copyWith(isLoading: false, successMessage: 'Photo approuvée');
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> rejectAvatarChange(String userId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(profileServiceProvider).rejectAvatarChange(userId);
      state = state.copyWith(isLoading: false, successMessage: 'Photo refusée');
      _ref.invalidate(allProfilesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Actions globales ────────────────────────────────────────────────────────

  Future<void> taxAll({
    required double percent,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref
          .read(profileServiceProvider)
          .taxAll(percent: percent, reason: reason);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Taxe de $percent% appliquée',
      );
      _ref.invalidate(allProfilesProvider);
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> rewardAll({
    required double amount,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref
          .read(profileServiceProvider)
          .rewardAll(amount: amount, reason: reason);
      state = state.copyWith(
        isLoading: false,
        successMessage: '$amount SC distribués',
      );
      _ref.invalidate(allProfilesProvider);
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Cours de la monnaie ─────────────────────────────────────────────────────

  Future<void> setManualRate({
    required double rate,
    required String reason,
    required List<double> demandPoints,
    required List<double> supplyPoints,
    required List<double> pricePoints,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(currencyServiceProvider).setManualRate(
            rate: rate,
            reason: reason,
            demandPoints: demandPoints,
            supplyPoints: supplyPoints,
            pricePoints: pricePoints,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Cours fixé à $rate',
      );
      _ref.invalidate(currentRateProvider);
      _ref.invalidate(rateHistoryProvider(30));
      _ref.invalidate(rateStatsProvider(30));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Marketplace admin ───────────────────────────────────────────────────────

  Future<void> createItem({
    required String name,
    required String description,
    required double price,
    required String category,
    required int stock,
    required int maxPerUser,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(marketplaceServiceProvider).createItem(
            name: name,
            description: description,
            price: price,
            category: category,
            stock: stock,
            maxPerUser: maxPerUser,
            imageUrl: imageUrl,
          );
      state = state.copyWith(isLoading: false, successMessage: 'Item créé');
      _ref.invalidate(marketplaceItemsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateItem({
    required String itemId,
    String? name,
    String? description,
    double? price,
    String? category,
    int? stock,
    int? maxPerUser,
    bool? isActive,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(marketplaceServiceProvider).updateItem(
            itemId: itemId,
            name: name,
            description: description,
            price: price,
            category: category,
            stock: stock,
            maxPerUser: maxPerUser,
            isActive: isActive,
            imageUrl: imageUrl,
          );
      state =
          state.copyWith(isLoading: false, successMessage: 'Item mis à jour');
      _ref.invalidate(marketplaceItemsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(marketplaceServiceProvider).deleteItem(itemId);
      state = state.copyWith(isLoading: false, successMessage: 'Item supprimé');
      _ref.invalidate(marketplaceItemsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Enchères admin ──────────────────────────────────────────────────────────

  Future<void> createAuction({
    required String itemName,
    required String itemDescription,
    required double startingPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(auctionServiceProvider).createAuction(
            itemName: itemName,
            itemDescription: itemDescription,
            startingPrice: startingPrice,
            startsAt: startsAt,
            endsAt: endsAt,
            itemImageUrl: imageUrl,
          );
      state = state.copyWith(isLoading: false, successMessage: 'Enchère créée');
      _ref.invalidate(activeAuctionsProvider);
      _ref.invalidate(allAuctionsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> cancelAuction(String auctionId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(auctionServiceProvider).cancelAuction(auctionId);
      state =
          state.copyWith(isLoading: false, successMessage: 'Enchère annulée');
      _ref.invalidate(activeAuctionsProvider);
      _ref.invalidate(allAuctionsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> finalizeAuction(String auctionId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(auctionServiceProvider).finalizeAuction(auctionId);
      state =
          state.copyWith(isLoading: false, successMessage: 'Enchère clôturée');
      _ref.invalidate(activeAuctionsProvider);
      _ref.invalidate(allAuctionsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Prêts admin ─────────────────────────────────────────────────────────────

  Future<void> deleteAuction(String auctionId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(auctionServiceProvider).deleteAuction(auctionId);
      state = state.copyWith(
          isLoading: false, successMessage: 'Enchère supprimée');
      _ref.invalidate(activeAuctionsProvider);
      _ref.invalidate(allAuctionsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> markLoanDefaulted(String loanId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(loanServiceProvider).markAsDefaulted(loanId);
      state = state.copyWith(
          isLoading: false, successMessage: 'Prêt marqué en défaut');
      _ref.invalidate(overdueLoansProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateLoanConfig(LoanConfig config) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _ref.read(loanServiceProvider).updateLoanConfig(config);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Configuration des prêts enregistrée',
      );
      _ref.invalidate(loanConfigProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);
}
