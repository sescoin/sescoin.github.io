import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/currency_rate.dart';

class CurrencyService {
  final SupabaseClient _client;

  CurrencyService(this._client);

  Future<CurrencyRate> getCurrentRate() async {
    final data = await _client
        .from(AppConstants.tableExchangeRates)
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    return CurrencyRate.fromJson(data);
  }

  Future<List<CurrencyRate>> getRateHistory({
    int days = AppConstants.exchangeRateHistoryDays,
  }) async {
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final data = await _client
        .from(AppConstants.tableExchangeRates)
        .select()
        .gte('created_at', since)
        .order('created_at', ascending: true);

    return (data as List).map((e) => CurrencyRate.fromJson(e)).toList();
  }

  Future<CurrencyRate?> getLastManualRate() async {
    final data = await _client
        .from(AppConstants.tableExchangeRates)
        .select()
        .eq('is_manual', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return CurrencyRate.fromJson(data);
  }

  Future<CurrencyRate> recalculateRate() async {
    final response = await _client.rpc('calculate_currency_rate');
    return CurrencyRate.fromJson(response as Map<String, dynamic>);
  }

  Future<CurrencyRate> setManualRate({
    required double rate,
    required String reason,
    required List<double> demandPoints,
    required List<double> supplyPoints,
    required List<double> pricePoints,
  }) async {
    if (rate <= 0) {
      throw Exception('Le taux doit etre positif.');
    }
    if (demandPoints.length != CurrencyRate.chartPointCount ||
        supplyPoints.length != CurrencyRate.chartPointCount ||
        pricePoints.length != CurrencyRate.chartPointCount) {
      throw Exception('Le graphique doit contenir 10 points.');
    }

    CurrencyRate? previous;
    try {
      previous = await getCurrentRate();
    } catch (_) {}

    final changePercent = previous != null && previous.rate != 0
        ? ((rate - previous.rate) / previous.rate) * 100
        : 0.0;

    final data = await _client
        .from(AppConstants.tableExchangeRates)
        .insert({
          'rate': rate,
          'change_percent': changePercent,
          'reason': reason,
          'is_manual': true,
          'demand_points': demandPoints,
          'supply_points': supplyPoints,
          'price_points': pricePoints,
        })
        .select()
        .single();

    return CurrencyRate.fromJson(data);
  }

  Future<CurrencyStats> getStats({
    int days = AppConstants.exchangeRateHistoryDays,
  }) async {
    final history = await getRateHistory(days: days);

    if (history.isEmpty) {
      return const CurrencyStats(
        min: AppConstants.exchangeRateBase,
        max: AppConstants.exchangeRateBase,
        average: AppConstants.exchangeRateBase,
        totalChangePercent: 0,
        dataPoints: 0,
      );
    }

    final rates = history.map((r) => r.rate).toList();
    final min = rates.reduce((a, b) => a < b ? a : b);
    final max = rates.reduce((a, b) => a > b ? a : b);
    final average = rates.reduce((a, b) => a + b) / rates.length;
    final totalChange = history.length > 1
        ? ((history.last.rate - history.first.rate) / history.first.rate) * 100
        : 0.0;

    return CurrencyStats(
      min: min,
      max: max,
      average: average,
      totalChangePercent: totalChange,
      dataPoints: history.length,
    );
  }

  Stream<CurrencyRate> watchCurrentRate() {
    return _client
        .from(AppConstants.tableExchangeRates)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          if (rows.isEmpty) {
            return CurrencyRate(
              id: 'default',
              rate: AppConstants.exchangeRateBase,
              changePercent: 0,
              isManual: false,
              createdAt: DateTime.now(),
              demandPoints: CurrencyRate.defaultDemandPoints,
              supplyPoints: CurrencyRate.defaultSupplyPoints,
              pricePoints: CurrencyRate.defaultPricePoints,
            );
          }
          return CurrencyRate.fromJson(rows.first);
        });
  }
}

class CurrencyStats {
  final double min;
  final double max;
  final double average;
  final double totalChangePercent;
  final int dataPoints;

  const CurrencyStats({
    required this.min,
    required this.max,
    required this.average,
    required this.totalChangePercent,
    required this.dataPoints,
  });

  bool get isPositiveTrend => totalChangePercent > 0;
  bool get isNegativeTrend => totalChangePercent < 0;
}
