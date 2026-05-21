import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'service_providers.dart';

final globalTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionServiceProvider).watchGlobalTransactions();
});

final globalTransactionsSnapshotProvider = FutureProvider<List<Transaction>>((ref) {
  return ref.watch(transactionServiceProvider).getGlobalTransactions();
});
