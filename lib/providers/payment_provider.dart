import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'auth_provider.dart';
import 'service_providers.dart';
import 'wallet_provider.dart';

class PaymentState {
  final bool isLoading;
  final String? error;
  final String? paymentToken;
  final double? requestedAmount;
  final Transaction? lastTransaction;
  final PaymentStep step;

  const PaymentState({
    this.isLoading = false,
    this.error,
    this.paymentToken,
    this.requestedAmount,
    this.lastTransaction,
    this.step = PaymentStep.idle,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    String? paymentToken,
    double? requestedAmount,
    Transaction? lastTransaction,
    PaymentStep? step,
    bool clearError = false,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      paymentToken: paymentToken ?? this.paymentToken,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      step: step ?? this.step,
    );
  }
}

enum PaymentStep {
  idle,
  requestCreated,
  confirming,
  success,
  error,
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});

class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref _ref;

  PaymentNotifier(this._ref) : super(const PaymentState());

  Future<String> createRequest({
    required double amount,
    String? description,
  }) async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Non connecté');
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token =
          await _ref.read(transactionServiceProvider).createPaymentRequest(
                recipientId: userId,
                amount: amount,
                description: description,
              );
      state = state.copyWith(
        isLoading: false,
        paymentToken: token,
        requestedAmount: amount,
        step: PaymentStep.requestCreated,
      );
      return token;
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        step: PaymentStep.error,
      );
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Transaction> confirmRequest(String paymentToken) async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Non connecté');
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      step: PaymentStep.confirming,
    );
    try {
      final tx =
          await _ref.read(transactionServiceProvider).confirmPaymentRequest(
                payerId: userId,
                paymentToken: paymentToken,
              );
      state = state.copyWith(
        isLoading: false,
        lastTransaction: tx,
        step: PaymentStep.success,
      );
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      return tx;
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        step: PaymentStep.error,
      );
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> acknowledgePayment(String transactionId) async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      await _ref.read(transactionServiceProvider).acknowledgePayment(
            recipientId: userId,
            transactionId: transactionId,
          );
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Transaction> sendTo({
    required String recipientId,
    required double amount,
    required String paymentMethod,
    String? description,
  }) async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Non connecté');
    }
    if (userId == recipientId) {
      throw Exception('Tu ne peux pas te payer toi-même');
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      step: PaymentStep.confirming,
    );
    try {
      final result = await _ref.read(supabaseClientProvider).rpc(
        'transfer_funds',
        params: {
          'p_from_user_id': userId,
          'p_to_user_id': recipientId,
          'p_amount': amount,
          'p_description':
              description ?? 'Paiement ${paymentMethod.toUpperCase()}',
          'p_metadata': {
            'payment_method': paymentMethod.toLowerCase(),
          },
        },
      );
      final tx = Transaction.fromJson(result as Map<String, dynamic>);
      state = state.copyWith(
        isLoading: false,
        lastTransaction: tx,
        step: PaymentStep.success,
      );
      await _ref.read(currentProfileProvider.notifier).refresh();
      _ref.read(walletProvider.notifier).loadInitial();
      return tx;
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        step: PaymentStep.error,
      );
      Error.throwWithStackTrace(e, st);
    }
  }

  void reset() => state = const PaymentState();
}
