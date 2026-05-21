import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/currency_rate.dart';
import '../services/currency_service.dart';
import 'service_providers.dart';

// ── Taux courant (realtime) ───────────────────────────────────────────────────
final currentRateProvider = StreamProvider<CurrencyRate>((ref) {
  return ref
      .watch(currencyServiceProvider)
      .watchCurrentRate()
      .handleError((_) {});
});

// ── Historique sur N jours ────────────────────────────────────────────────────
final rateHistoryProvider =
    FutureProvider.family<List<CurrencyRate>, int>((ref, days) {
  return ref.watch(currencyServiceProvider).getRateHistory(days: days);
});

// ── Stats sur N jours ─────────────────────────────────────────────────────────
final rateStatsProvider =
    FutureProvider.family<CurrencyStats, int>((ref, days) {
  return ref.watch(currencyServiceProvider).getStats(days: days);
});
