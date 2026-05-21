import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/loan.dart';
import 'auth_provider.dart';
import 'service_providers.dart';
import 'wallet_provider.dart';

// ── Prêts en temps réel ───────────────────────────────────────────────────────
final userLoansProvider = StreamProvider<List<Loan>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(loanServiceProvider).watchUserLoans(userId);
});

// ── Prêts en tant qu'emprunteur ───────────────────────────────────────────────
final borrowedLoansProvider = FutureProvider<List<Loan>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(loanServiceProvider).getBorrowedLoans(userId);
});

// ── Prêts en tant que prêteur ─────────────────────────────────────────────────
final lentLoansProvider = FutureProvider<List<Loan>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(loanServiceProvider).getLentLoans(userId);
});

// ── Actions sur les prêts ─────────────────────────────────────────────────────

class LoanActionState {
  final bool isLoading;
  final String? error;
  final Loan? lastLoan;

  const LoanActionState({
    this.isLoading = false,
    this.error,
    this.lastLoan,
  });

  LoanActionState copyWith({
    bool? isLoading,
    String? error,
    Loan? lastLoan,
    bool clearError = false,
  }) {
    return LoanActionState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastLoan: lastLoan ?? this.lastLoan,
    );
  }
}

final loanActionProvider =
    StateNotifierProvider<LoanActionNotifier, LoanActionState>((ref) {
  return LoanActionNotifier(ref);
});

class LoanActionNotifier extends StateNotifier<LoanActionState> {
  final Ref _ref;

  LoanActionNotifier(this._ref) : super(const LoanActionState());

  Future<Loan> requestLoan({
    required String lenderUsername,
    required double principal,
    required double interestRate,
    DateTime? dueDate,
    String? note,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loan = await _ref.read(loanServiceProvider).requestLoan(
            borrowerId: userId,
            lenderUsername: lenderUsername,
            principal: principal,
            interestRate: interestRate,
            dueDate: dueDate,
            note: note,
          );
      state = state.copyWith(isLoading: false, lastLoan: loan);
      return loan;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Loan> acceptLoan(String loanId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loan =
          await _ref.read(loanServiceProvider).acceptLoan(loanId, userId);
      state = state.copyWith(isLoading: false, lastLoan: loan);
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      return loan;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Loan> rejectLoan(String loanId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loan =
          await _ref.read(loanServiceProvider).rejectLoan(loanId, userId);
      state = state.copyWith(isLoading: false, lastLoan: loan);
      return loan;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Loan> cancelLoan(String loanId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loan =
          await _ref.read(loanServiceProvider).cancelLoan(loanId, userId);
      state = state.copyWith(isLoading: false, lastLoan: loan);
      return loan;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Loan> repayLoan({
    required String loanId,
    required double amount,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw Exception('Non connecté');

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loan = await _ref.read(loanServiceProvider).repayLoan(
            loanId: loanId,
            borrowerId: userId,
            amount: amount,
          );
      state = state.copyWith(isLoading: false, lastLoan: loan);
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      return loan;
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      Error.throwWithStackTrace(e, st);
    }
  }

  void reset() => state = const LoanActionState();
}
