import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/currency_rate.dart';
import '../../providers/currency_provider.dart';
import '../common/loading_overlay.dart';

class CurrencyChart extends ConsumerWidget {
  const CurrencyChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateAsync = ref.watch(currentRateProvider);

    return rateAsync.when(
      loading: () => const SizedBox(
        height: 380,
        child: InlineLoader(),
      ),
      error: (_, __) => const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Impossible de charger le graphique',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
      data: (rate) => _MarketChartCard(rate: rate),
    );
  }
}

class _MarketChartCard extends StatelessWidget {
  const _MarketChartCard({required this.rate});

  final CurrencyRate rate;

  @override
  Widget build(BuildContext context) {
    final maxVolume = math.max(
      rate.demandPoints.reduce(math.max),
      rate.supplyPoints.reduce(math.max),
    );
    final maxPrice = _roundPriceCeiling(rate.chartMaxPrice);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Evolution du prix en fonction de l'offre et la demande",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prix actuel : ${rate.rate.toStringAsFixed(2)} EUR / ${rate.rate.toStringAsFixed(2)} SC',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Wrap(
              spacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LegendItem(
                  color: Color(0xFFF44336),
                  label: 'Demande',
                  isLine: false,
                ),
                _LegendItem(
                  color: Color(0xFFFFC107),
                  label: 'Offre',
                  isLine: false,
                ),
                _LegendItem(
                  color: Color(0xFF4285F4),
                  label: 'Prix',
                  isLine: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 270,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _MarketChartPainter(
                            demandPoints: rate.demandPoints,
                            supplyPoints: rate.supplyPoints,
                            pricePoints: rate.pricePoints,
                            maxVolume: maxVolume <= 0 ? 1 : maxVolume,
                            maxPrice: maxPrice <= 0 ? 1 : maxPrice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RightAxis(maxPrice: maxPrice),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    ...List.generate(CurrencyRate.chartPointCount, (index) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 44),
                  ],
                ),
              ],
            ),
          ),
          if ((rate.reason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rate.reason!.trim(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static double _roundPriceCeiling(double value) {
    if (value <= 10) return 10;
    return ((value / 10).ceil() * 10).toDouble();
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.isLine,
  });

  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isLine
            ? Container(width: 12, height: 3, color: color)
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RightAxis extends StatelessWidget {
  const _RightAxis({required this.maxPrice});

  final double maxPrice;

  @override
  Widget build(BuildContext context) {
    final steps = [
      maxPrice,
      maxPrice * 0.75,
      maxPrice * 0.5,
      maxPrice * 0.25,
      0.0,
    ];

    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.map((value) {
          return Text(
            '${value.toStringAsFixed(2).replaceAll('.', ',')} EUR',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  _MarketChartPainter({
    required this.demandPoints,
    required this.supplyPoints,
    required this.pricePoints,
    required this.maxVolume,
    required this.maxPrice,
  });

  final List<double> demandPoints;
  final List<double> supplyPoints;
  final List<double> pricePoints;
  final double maxVolume;
  final double maxPrice;

  @override
  void paint(Canvas canvas, Size size) {
    const gridColor = Color(0xFF8B8B8B);
    const demandColor = Color(0xFFF44336);
    const supplyColor = Color(0xFFFFC107);
    const lineColor = Color(0xFF4285F4);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.1;
    final demandPaint = Paint()..color = demandColor;
    final supplyPaint = Paint()..color = supplyColor;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );
    const smallStyle = TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    for (var i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawLine(
      Offset(0, size.height - bottomPadding),
      Offset(size.width, size.height - bottomPadding),
      axisPaint,
    );

    final groupWidth = size.width / CurrencyRate.chartPointCount;
    final barWidth = groupWidth * 0.30;
    final chartBottom = size.height - bottomPadding;
    final linePath = Path();

    for (var i = 0; i < CurrencyRate.chartPointCount; i++) {
      final centerX = groupWidth * i + groupWidth / 2;
      final demandHeight = (demandPoints[i] / maxVolume) * (chartHeight * 0.88);
      final supplyHeight = (supplyPoints[i] / maxVolume) * (chartHeight * 0.88);
      final demandRect = Rect.fromLTWH(
        centerX - barWidth - 1,
        chartBottom - demandHeight,
        barWidth,
        demandHeight,
      );
      final supplyRect = Rect.fromLTWH(
        centerX + 1,
        chartBottom - supplyHeight,
        barWidth,
        supplyHeight,
      );

      canvas.drawRect(demandRect, demandPaint);
      canvas.drawRect(supplyRect, supplyPaint);

      final priceY =
          chartBottom - (pricePoints[i] / maxPrice) * (chartHeight * 0.96);
      if (i == 0) {
        linePath.moveTo(centerX, priceY);
      } else {
        linePath.lineTo(centerX, priceY);
      }

      final demandText = demandPoints[i].toStringAsFixed(0);
      final supplyText = supplyPoints[i].toStringAsFixed(0);

      textPainter.text = TextSpan(
        text: demandText,
        style: demandPoints[i] > 0
            ? labelStyle
            : smallStyle.copyWith(color: demandColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX - barWidth - 1 + (barWidth - textPainter.width) / 2,
          demandPoints[i] > 0
              ? math.max(topPadding, demandRect.top + 4)
              : chartBottom - 22,
        ),
      );

      textPainter.text = TextSpan(
        text: supplyText,
        style: supplyPoints[i] > 0
            ? smallStyle.copyWith(color: Colors.black87)
            : smallStyle.copyWith(color: supplyColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX + 1 + (barWidth - textPainter.width) / 2,
          supplyPoints[i] > 0
              ? math.max(topPadding, supplyRect.top + 4)
              : chartBottom - 22,
        ),
      );
    }

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) {
    return oldDelegate.demandPoints != demandPoints ||
        oldDelegate.supplyPoints != supplyPoints ||
        oldDelegate.pricePoints != pricePoints ||
        oldDelegate.maxVolume != maxVolume ||
        oldDelegate.maxPrice != maxPrice;
  }
}
