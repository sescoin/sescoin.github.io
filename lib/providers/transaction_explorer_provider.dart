import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'service_providers.dart';

final globalTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionServiceProvider).watchGlobalTransactions();
});

final globalTransactionsSnapshotProvider = FutureProvider<List<Transaction>>((ref) {
  return ref.watch(transactionServiceProvider).getGlobalTransactions();
});

/// Transactions d'un utilisateur donné (chargement unique, côté serveur).
/// Bien plus léger que de filtrer le flux temps réel global.
final userTransactionsProvider =
    FutureProvider.family<List<Transaction>, String>((ref, userId) {
  return ref
      .watch(transactionServiceProvider)
      .getTransactions(userId: userId, pageSize: 40);
});
