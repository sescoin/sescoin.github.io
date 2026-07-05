import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/animations.dart';
import '../core/theme.dart';
import '../models/currency_rate.dart';
import '../providers/currency_provider.dart';
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
      error: (_, __) => SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Impossible de charger le graphique',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      data: (rate) => _MarketChartCard(rate: rate),
    );
  }
}

class _MarketChartCard extends StatefulWidget {
  const _MarketChartCard({required this.rate});

  final CurrencyRate rate;

  @override
  State<_MarketChartCard> createState() => _MarketChartCardState();
}

class _MarketChartCardState extends State<_MarketChartCard> {
  CurrencyRate get rate => widget.rate;

  /// Point de prix touché : sa valeur exacte s'affiche quelques secondes.
  int? _selectedIndex;
  Timer? _selectionTimer;

  @override
  void dispose() {
    _selectionTimer?.cancel();
    super.dispose();
  }

  void _onChartTap(Offset local, double width) {
    final index = ((local.dx / width) * CurrencyRate.chartPointCount)
        .floor()
        .clamp(0, CurrencyRate.chartPointCount - 1);
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
    _selectionTimer?.cancel();
    if (_selectedIndex != null) {
      _selectionTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _selectedIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final onVariant = theme.colorScheme.onSurfaceVariant;

    final maxVolume = math.max(
      rate.demandPoints.reduce(math.max),
      rate.supplyPoints.reduce(math.max),
    );
    final maxPrice = _roundPriceCeiling(rate.chartMaxPrice);
    final priceLabel = rate.rate.toStringAsFixed(2).replaceAll('.', ',');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights_rounded, color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Évolution du prix',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Selon l'offre et la demande",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: onVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$priceLabel €',
                        style: TextStyle(
                          color: AppTheme.onAccent(accent),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '1 SC',
                        style: TextStyle(
                          color: AppTheme.onAccent(accent)
                              .withValues(alpha: 0.75),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Légende ─────────────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                _LegendPill(
                  color: AppTheme.negative,
                  label: 'Demande',
                  isLine: false,
                ),
                _LegendPill(
                  color: AppTheme.positive,
                  label: 'Offre',
                  isLine: false,
                ),
                _LegendPill(color: null, label: 'Prix', isLine: true),
              ],
            ),
            const SizedBox(height: 14),
            // ── Graphique ───────────────────────────────────────────────────
            SizedBox(
              height: 250,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            _onChartTap(d.localPosition, constraints.maxWidth),
                        child: _AnimatedChart(
                          demandPoints: rate.demandPoints,
                          supplyPoints: rate.supplyPoints,
                          pricePoints: rate.pricePoints,
                          maxVolume: maxVolume <= 0 ? 1 : maxVolume,
                          maxPrice: maxPrice <= 0 ? 1 : maxPrice,
                          accent: accent,
                          surface: theme.cardColor,
                          gridColor: onSurface.withValues(alpha: 0.08),
                          labelColor: onVariant,
                          selectedIndex: _selectedIndex,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RightAxis(maxPrice: maxPrice, color: onVariant),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Axe horizontal ──────────────────────────────────────────────
            Row(
              children: [
                ...List.generate(CurrencyRate.chartPointCount, (index) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: onVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 52),
              ],
            ),
            if ((rate.reason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rate.reason!.trim(),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _roundPriceCeiling(double value) {
    if (value <= 10) return 10;
    return ((value / 10).ceil() * 10).toDouble();
  }
}

// ── Pastille de légende ────────────────────────────────────────────────────────

class _LegendPill extends StatelessWidget {
  const _LegendPill({
    required this.color,
    required this.label,
    required this.isLine,
  });

  /// null = couleur d'accent du thème (ligne de prix).
  final Color? color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLine
              ? Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              : Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Axe des prix ───────────────────────────────────────────────────────────────

class _RightAxis extends StatelessWidget {
  const _RightAxis({required this.maxPrice, required this.color});

  final double maxPrice;
  final Color color;

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
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.map((value) {
          return Text(
            '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAll('.', ',')} €',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Graphique animé ────────────────────────────────────────────────────────────

class _AnimatedChart extends StatelessWidget {
  const _AnimatedChart({
    required this.demandPoints,
    required this.supplyPoints,
    required this.pricePoints,
    required this.maxVolume,
    required this.maxPrice,
    required this.accent,
    required this.surface,
    required this.gridColor,
    required this.labelColor,
    this.selectedIndex,
  });

  final List<double> demandPoints;
  final List<double> supplyPoints;
  final List<double> pricePoints;
  final double maxVolume;
  final double maxPrice;
  final Color accent;
  final Color surface;
  final Color gridColor;
  final Color labelColor;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce) {
      return CustomPaint(painter: _painter(1.0));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) =>
          CustomPaint(painter: _painter(progress)),
    );
  }

  _MarketChartPainter _painter(double progress) => _MarketChartPainter(
        demandPoints: demandPoints,
        supplyPoints: supplyPoints,
        pricePoints: pricePoints,
        maxVolume: maxVolume,
        maxPrice: maxPrice,
        accent: accent,
        surface: surface,
        gridColor: gridColor,
        labelColor: labelColor,
        progress: progress,
        selectedIndex: selectedIndex,
      );
}

class _MarketChartPainter extends CustomPainter {
  _MarketChartPainter({
    required this.demandPoints,
    required this.supplyPoints,
    required this.pricePoints,
    required this.maxVolume,
    required this.maxPrice,
    required this.accent,
    required this.surface,
    required this.gridColor,
    required this.labelColor,
    required this.progress,
    this.selectedIndex,
  });

  final List<double> demandPoints;
  final List<double> supplyPoints;
  final List<double> pricePoints;
  final double maxVolume;
  final double maxPrice;
  final Color accent;
  final Color surface;
  final Color gridColor;
  final Color labelColor;

  /// 0 → 1 : les barres grandissent et la ligne se trace.
  final double progress;

  /// Point de prix touché par l'utilisateur (affiche sa valeur exacte).
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const demandColor = AppTheme.negative;
    const supplyColor = AppTheme.positive;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final demandPaint = Paint()..color = demandColor.withValues(alpha: 0.88);
    final supplyPaint = Paint()..color = supplyColor.withValues(alpha: 0.88);
    final lineHalo = Paint()
      ..color = surface
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const topPadding = 16.0;
    const bottomPadding = 4.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartBottom = size.height - bottomPadding;

    // Grille horizontale
    for (var i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final groupWidth = size.width / CurrencyRate.chartPointCount;
    final barWidth = groupWidth * 0.26;
    const barGap = 3.0;
    final linePath = Path();

    for (var i = 0; i < CurrencyRate.chartPointCount; i++) {
      final centerX = groupWidth * i + groupWidth / 2;
      final demandHeight =
          (demandPoints[i] / maxVolume) * (chartHeight * 0.85) * progress;
      final supplyHeight =
          (supplyPoints[i] / maxVolume) * (chartHeight * 0.85) * progress;

      final demandRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX - barWidth - barGap / 2,
          chartBottom - demandHeight,
          barWidth,
          demandHeight,
        ),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      final supplyRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centerX + barGap / 2,
          chartBottom - supplyHeight,
          barWidth,
          supplyHeight,
        ),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      if (demandHeight > 0) canvas.drawRRect(demandRect, demandPaint);
      if (supplyHeight > 0) canvas.drawRRect(supplyRect, supplyPaint);

      final priceY =
          chartBottom - (pricePoints[i] / maxPrice) * (chartHeight * 0.94);
      if (i == 0) {
        linePath.moveTo(centerX, priceY);
      } else {
        linePath.lineTo(centerX, priceY);
      }

      // Valeurs au-dessus des barres (affichées en fin d'animation)
      if (progress > 0.85) {
        final labelAlpha = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
        _paintBarLabel(
          canvas,
          textPainter,
          value: demandPoints[i],
          color: demandColor.withValues(alpha: labelAlpha),
          fadedColor: labelColor.withValues(alpha: 0.55 * labelAlpha),
          centerX: centerX - barGap / 2 - barWidth / 2,
          barTop: chartBottom - demandHeight,
          chartBottom: chartBottom,
        );
        _paintBarLabel(
          canvas,
          textPainter,
          value: supplyPoints[i],
          color: supplyColor.withValues(alpha: labelAlpha),
          fadedColor: labelColor.withValues(alpha: 0.55 * labelAlpha),
          centerX: centerX + barGap / 2 + barWidth / 2,
          barTop: chartBottom - supplyHeight,
          chartBottom: chartBottom,
        );
      }
    }

    // Ligne de prix : tracée progressivement, avec un halo pour rester
    // lisible par-dessus les barres.
    final metrics = linePath.computeMetrics().toList();
    for (final metric in metrics) {
      final partial = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(partial, lineHalo);
      canvas.drawPath(partial, linePaint);
    }

    // Points sur la ligne
    if (progress >= 1.0) {
      final dotFill = Paint()..color = accent;
      final dotStroke = Paint()
        ..color = surface
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < CurrencyRate.chartPointCount; i++) {
        final centerX = groupWidth * i + groupWidth / 2;
        final priceY =
            chartBottom - (pricePoints[i] / maxPrice) * (chartHeight * 0.94);
        canvas.drawCircle(Offset(centerX, priceY), 3.4, dotFill);
        canvas.drawCircle(Offset(centerX, priceY), 3.4, dotStroke);
      }
    }

    // Valeur exacte du point de prix touché
    if (selectedIndex != null && progress >= 1.0) {
      final i = selectedIndex!;
      final centerX = groupWidth * i + groupWidth / 2;
      final priceY =
          chartBottom - (pricePoints[i] / maxPrice) * (chartHeight * 0.94);
      final anchor = Offset(centerX, priceY);

      // Point mis en avant
      canvas.drawCircle(anchor, 6, Paint()..color = accent);
      canvas.drawCircle(
        anchor,
        6,
        Paint()
          ..color = surface
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );

      // Badge avec la valeur exacte
      textPainter.text = TextSpan(
        text: '${pricePoints[i].toStringAsFixed(2).replaceAll('.', ',')} €',
        style: TextStyle(
          color: accent,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      );
      textPainter.layout();
      final dx = (anchor.dx - textPainter.width / 2)
          .clamp(2.0, size.width - textPainter.width - 2.0);
      final above = anchor.dy - textPainter.height - 16;
      final dy = above < 2 ? anchor.dy + 12 : above;
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          dx - 6,
          dy - 4,
          textPainter.width + 12,
          textPainter.height + 8,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = surface.withValues(alpha: 0.94),
      );
      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  void _paintBarLabel(
    Canvas canvas,
    TextPainter textPainter, {
    required double value,
    required Color color,
    required Color fadedColor,
    required double centerX,
    required double barTop,
    required double chartBottom,
  }) {
    final hasValue = value > 0;
    textPainter.text = TextSpan(
      text: value.toStringAsFixed(0),
      style: TextStyle(
        color: hasValue ? color : fadedColor,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        hasValue ? barTop - textPainter.height - 3 : chartBottom - 14,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) {
    return oldDelegate.demandPoints != demandPoints ||
        oldDelegate.supplyPoints != supplyPoints ||
        oldDelegate.pricePoints != pricePoints ||
        oldDelegate.maxVolume != maxVolume ||
        oldDelegate.maxPrice != maxPrice ||
        oldDelegate.accent != accent ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
