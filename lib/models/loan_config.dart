class LoanConfig {
  const LoanConfig({
    required this.maxDailySc,
    required this.maxWeeklySc,
    required this.maxActiveLoans,
    required this.maxDurationDays,
    required this.maxInterestRate,
    required this.minBalanceSc,
  });

  final double maxDailySc;
  final double maxWeeklySc;
  final int maxActiveLoans;
  final int maxDurationDays;
  final double maxInterestRate;
  final double minBalanceSc;

  factory LoanConfig.fromJson(Map<String, dynamic> json) {
    return LoanConfig(
      maxDailySc: (json['max_daily_sc'] as num).toDouble(),
      maxWeeklySc: (json['max_weekly_sc'] as num).toDouble(),
      maxActiveLoans: json['max_active_loans'] as int,
      maxDurationDays: json['max_duration_days'] as int,
      maxInterestRate: (json['max_interest_rate'] as num).toDouble(),
      minBalanceSc: (json['min_balance_sc'] as num).toDouble(),
    );
  }

  static const defaults = LoanConfig(
    maxDailySc: 5000,
    maxWeeklySc: 1000,
    maxActiveLoans: 3,
    maxDurationDays: 14,
    maxInterestRate: 100,
    minBalanceSc: 10,
  );
}
