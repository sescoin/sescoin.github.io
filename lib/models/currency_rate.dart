class CurrencyRate {
  static const int chartPointCount = 10;
  static const List<double> defaultDemandPoints = [
    0,
    189,
    180,
    147,
    705,
    0,
    0,
    0,
    0,
    0,
  ];
  static const List<double> defaultSupplyPoints = [
    0,
    161,
    29,
    138,
    139,
    0,
    0,
    0,
    0,
    0,
  ];
  static const List<double> defaultPricePoints = [
    1.0,
    1.1,
    7.2,
    7.7,
    39.3,
    39.3,
    39.3,
    39.3,
    39.3,
    39.3,
  ];

  final String id;
  final double rate;
  final double changePercent;
  final String? reason;
  final bool isManual;
  final DateTime createdAt;
  final List<double> demandPoints;
  final List<double> supplyPoints;
  final List<double> pricePoints;

  const CurrencyRate({
    required this.id,
    required this.rate,
    required this.changePercent,
    this.reason,
    required this.isManual,
    required this.createdAt,
    required this.demandPoints,
    required this.supplyPoints,
    required this.pricePoints,
  });

  bool get isUp => changePercent > 0;
  bool get isDown => changePercent < 0;
  bool get isStable => changePercent == 0;
  double get chartMaxPrice => pricePoints.reduce((a, b) => a > b ? a : b);

  static List<double> _seriesFromJson(dynamic value, List<double> fallback) {
    if (value is List) {
      final parsed = value
          .map((e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0)
          .toList();
      if (parsed.length == chartPointCount) return parsed;
      if (parsed.length > chartPointCount) {
        return parsed.take(chartPointCount).toList();
      }
      return [...parsed, ...fallback.skip(parsed.length)];
    }
    return List<double>.from(fallback);
  }

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    final rateValue = (json['rate'] as num).toDouble();
    final fallbackPrices = [
      ...defaultPricePoints.take(chartPointCount - 1),
      rateValue,
    ];

    return CurrencyRate(
      id: json['id'] as String,
      rate: rateValue,
      changePercent: (json['change_percent'] as num).toDouble(),
      reason: json['reason'] as String?,
      isManual: json['is_manual'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      demandPoints: _seriesFromJson(
        json['demand_points'],
        defaultDemandPoints,
      ),
      supplyPoints: _seriesFromJson(
        json['supply_points'],
        defaultSupplyPoints,
      ),
      pricePoints: _seriesFromJson(
        json['price_points'],
        fallbackPrices,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rate': rate,
      'change_percent': changePercent,
      'reason': reason,
      'is_manual': isManual,
      'created_at': createdAt.toIso8601String(),
      'demand_points': demandPoints,
      'supply_points': supplyPoints,
      'price_points': pricePoints,
    };
  }

  CurrencyRate copyWith({
    String? id,
    double? rate,
    double? changePercent,
    String? reason,
    bool? isManual,
    DateTime? createdAt,
    List<double>? demandPoints,
    List<double>? supplyPoints,
    List<double>? pricePoints,
  }) {
    return CurrencyRate(
      id: id ?? this.id,
      rate: rate ?? this.rate,
      changePercent: changePercent ?? this.changePercent,
      reason: reason ?? this.reason,
      isManual: isManual ?? this.isManual,
      createdAt: createdAt ?? this.createdAt,
      demandPoints: demandPoints ?? this.demandPoints,
      supplyPoints: supplyPoints ?? this.supplyPoints,
      pricePoints: pricePoints ?? this.pricePoints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyRate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CurrencyRate(rate: $rate, change: $changePercent%, manual: $isManual)';
}
