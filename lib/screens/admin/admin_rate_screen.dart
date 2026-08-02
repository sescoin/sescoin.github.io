import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/dispose_scope.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/currency_rate.dart';
import '../../providers/admin_provider.dart';
import '../../providers/currency_provider.dart';

/// Série éditable du graphique.
enum _Series { demand, supply, price }

extension on _Series {
  String get label => switch (this) {
        _Series.demand => 'Demande',
        _Series.supply => 'Offre',
        _Series.price => 'Prix',
      };

  IconData get icon => switch (this) {
        _Series.demand => Icons.shopping_cart_rounded,
        _Series.supply => Icons.inventory_2_rounded,
        _Series.price => Icons.show_chart_rounded,
      };
}

class AdminRateScreen extends ConsumerStatefulWidget {
  const AdminRateScreen({super.key});

  @override
  ConsumerState<AdminRateScreen> createState() => _AdminRateScreenState();
}

class _AdminRateScreenState extends ConsumerState<AdminRateScreen> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _reasonCtrl;

  late List<double> _demand;
  late List<double> _supply;
  late List<double> _price;

  // État de référence pour détecter les modifications non enregistrées.
  late List<double> _baseDemand;
  late List<double> _baseSupply;
  late List<double> _basePrice;
  late String _baseRate;
  late String _baseReason;

  _Series _series = _Series.price;

  /// Échelles gelées pendant le glissement pour éviter l'effet élastique.
  double _volumeAxisMax = 100;
  double _priceAxisMax = 10;

  int? _dragIndex;
  int _lastHapticIndex = -1;

  @override
  void initState() {
    super.initState();
    final current = _currentOrDefault();
    _rateCtrl = TextEditingController(text: current.rate.toStringAsFixed(4));
    _reasonCtrl = TextEditingController(text: current.reason ?? '');
    _demand = List.of(current.demandPoints);
    _supply = List.of(current.supplyPoints);
    _price = List.of(current.pricePoints);
    _baseDemand = List.of(current.demandPoints);
    _baseSupply = List.of(current.supplyPoints);
    _basePrice = List.of(current.pricePoints);
    _baseRate = _rateCtrl.text;
    _baseReason = _reasonCtrl.text;
    _recomputeAxes();
  }

  bool get _isDirty =>
      _rateCtrl.text != _baseRate ||
      _reasonCtrl.text != _baseReason ||
      !listEquals(_demand, _baseDemand) ||
      !listEquals(_supply, _baseSupply) ||
      !listEquals(_price, _basePrice);

  Future<void> _confirmExit() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text(
          'Les changements apportés au cours n\'ont pas été appliqués. '
          'Quitter sans enregistrer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer l\'édition'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  CurrencyRate _currentOrDefault() {
    return ref.read(currentRateProvider).valueOrNull ??
        CurrencyRate(
          id: 'default',
          rate: 1.0,
          changePercent: 0,
          isManual: false,
          createdAt: DateTime.now(),
          demandPoints: CurrencyRate.defaultDemandPoints,
          supplyPoints: CurrencyRate.defaultSupplyPoints,
          pricePoints: CurrencyRate.defaultPricePoints,
        );
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Échelles ────────────────────────────────────────────────────────────────

  static double _niceCeil(double value, {required double minimum}) {
    if (value <= minimum) return minimum;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
    for (final factor in [1, 2, 5, 10]) {
      final candidate = magnitude * factor;
      if (candidate >= value) return candidate.toDouble();
    }
    return (magnitude * 10).toDouble();
  }

  void _recomputeAxes() {
    final maxVolume = math.max(
      _demand.reduce(math.max),
      _supply.reduce(math.max),
    );
    _volumeAxisMax = _niceCeil(maxVolume * 1.3, minimum: 100);
    _priceAxisMax = _niceCeil(_price.reduce(math.max) * 1.3, minimum: 10);
  }

  List<double> get _activePoints => switch (_series) {
        _Series.demand => _demand,
        _Series.supply => _supply,
        _Series.price => _price,
      };

  double get _activeAxisMax =>
      _series == _Series.price ? _priceAxisMax : _volumeAxisMax;

  // ── Édition ─────────────────────────────────────────────────────────────────

  void _setPoint(int index, double rawValue) {
    final value = _series == _Series.price
        ? (rawValue * 100).roundToDouble() / 100 // pas de 0,01 €
        : rawValue.roundToDouble(); // volumes entiers
    setState(() => _activePoints[index] = value.clamp(0, _activeAxisMax));
  }

  /// Formate un prix en retirant les zéros inutiles (jusqu'à 4 décimales),
  /// pour pouvoir éditer des valeurs très proches de zéro.
  static String _formatPrice(double value) {
    var text = value.toStringAsFixed(4);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  void _onDragAt(Offset local, Size size) {
    final index = ((local.dx / size.width) * CurrencyRate.chartPointCount)
        .floor()
        .clamp(0, CurrencyRate.chartPointCount - 1);
    const topPad = _EditableChartPainter.topPadding;
    const bottomPad = _EditableChartPainter.bottomPadding;
    final chartHeight = size.height - topPad - bottomPad;
    final fraction =
        (1 - (local.dy - topPad) / chartHeight).clamp(0.0, 1.0);
    if (index != _lastHapticIndex) {
      HapticFeedback.selectionClick();
      _lastHapticIndex = index;
    }
    _dragIndex = index;
    _setPoint(index, fraction * _activeAxisMax);
  }

  void _onDragEnd() {
    setState(() {
      _dragIndex = null;
      _lastHapticIndex = -1;
      _recomputeAxes();
    });
  }

  Future<void> _editExactValue(int index) async {
    final ctrl = TextEditingController(
      text: _series == _Series.price
          ? _formatPrice(_activePoints[index])
          : _activePoints[index].toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [ctrl],
        child: AlertDialog(
          title: Text('${_series.label} — point ${index + 1}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Valeur exacte',
              suffixText: _series == _Series.price ? 'EUR' : 'SC',
            ),
            onSubmitted: (_) => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                double.tryParse(ctrl.text.replaceAll(',', '.')),
              ),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result < 0) return;
    setState(() {
      _activePoints[index] =
          _series == _Series.price ? (result * 10000).round() / 10000 : result;
      _recomputeAxes();
    });
  }

  void _resetFromCurrent() {
    final current = _currentOrDefault();
    setState(() {
      _demand = List.of(current.demandPoints);
      _supply = List.of(current.supplyPoints);
      _price = List.of(current.pricePoints);
      _rateCtrl.text = current.rate.toStringAsFixed(4);
      _reasonCtrl.text = current.reason ?? '';
      _recomputeAxes();
    });
  }

  void _clearPoints() {
    setState(() {
      _demand = List.filled(CurrencyRate.chartPointCount, 0);
      _supply = List.filled(CurrencyRate.chartPointCount, 0);
      _price = List.filled(CurrencyRate.chartPointCount, 0);
      _recomputeAxes();
    });
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0;
    if (rate <= 0) {
      AppFeedback.warning(context, 'Le cours affiché doit être positif.');
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).setManualRate(
            rate: rate,
            reason: _reasonCtrl.text.trim().isEmpty
                ? 'Modification manuelle du cours'
                : _reasonCtrl.text.trim(),
            demandPoints: List.of(_demand),
            supplyPoints: List.of(_supply),
            pricePoints: List.of(_price),
          );
      if (!mounted) return;
      AppFeedback.success(context, 'Cours fixé à ${rate.toStringAsFixed(4)}.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final current = ref.watch(currentRateProvider).valueOrNull;
    final state = ref.watch(adminActionsProvider);

    final seriesColor = switch (_series) {
      _Series.demand => AppTheme.negative,
      _Series.supply => AppTheme.positive,
      _Series.price => accent,
    };

    return PopScope(
      // Intercepte le retour pour avertir si des changements sont en attente.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: LoadingOverlay(
        isLoading: state.isLoading,
        child: Scaffold(
          appBar: AppBar(title: const Text('Modifier le cours')),
          body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            FadeSlideIn.staggered(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.touch_app_rounded,
                          color: accent, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cours actuel : ${(current?.rate ?? 1).toStringAsFixed(4)} EUR',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choisissez une série, puis faites glisser votre '
                            'doigt sur le graphique pour dessiner la courbe. '
                            'Appui long sur une colonne : valeur exacte.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Sélecteur de série ──────────────────────────────────────────
            FadeSlideIn.staggered(
              index: 1,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Series>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor:
                        seriesColor.withValues(alpha: 0.16),
                    selectedForegroundColor: seriesColor,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  segments: [
                    for (final s in _Series.values)
                      ButtonSegment(
                        value: s,
                        label: Text(s.label),
                        icon: Icon(s.icon, size: 15),
                      ),
                  ],
                  selected: {_series},
                  onSelectionChanged: (selection) => setState(() {
                    _series = selection.first;
                    _recomputeAxes();
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Graphique interactif ────────────────────────────────────────
            FadeSlideIn.staggered(
              index: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 280,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanDown: (d) => setState(
                                      () => _onDragAt(d.localPosition, size),
                                    ),
                                    onPanUpdate: (d) => setState(
                                      () => _onDragAt(d.localPosition, size),
                                    ),
                                    onPanEnd: (_) => _onDragEnd(),
                                    onPanCancel: _onDragEnd,
                                    onLongPressStart: (d) {
                                      final index = ((d.localPosition.dx /
                                                  size.width) *
                                              CurrencyRate.chartPointCount)
                                          .floor()
                                          .clamp(
                                            0,
                                            CurrencyRate.chartPointCount - 1,
                                          );
                                      _editExactValue(index);
                                    },
                                    child: CustomPaint(
                                      painter: _EditableChartPainter(
                                        demand: _demand,
                                        supply: _supply,
                                        price: _price,
                                        volumeAxisMax: _volumeAxisMax,
                                        priceAxisMax: _priceAxisMax,
                                        series: _series,
                                        accent: accent,
                                        surface: theme.cardColor,
                                        gridColor: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.08),
                                        labelColor:
                                            theme.colorScheme.onSurfaceVariant,
                                        dragIndex: _dragIndex,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            _AxisLabels(
                              axisMax: _activeAxisMax,
                              isPrice: _series == _Series.price,
                              color: seriesColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...List.generate(CurrencyRate.chartPointCount,
                              (index) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 54),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── Actions rapides ─────────────────────────────────────────────
            FadeSlideIn.staggered(
              index: 3,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetFromCurrent,
                      icon: const Icon(Icons.restore_rounded, size: 17),
                      label: const Text('Rétablir'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearPoints,
                      icon: const Icon(Icons.layers_clear_rounded, size: 17),
                      label: const Text('Tout à zéro'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.negative,
                        side: BorderSide(
                          color: AppTheme.negative.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ── Cours affiché + raison ──────────────────────────────────────
            FadeSlideIn.staggered(
              index: 4,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Cours affiché (EUR)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Tooltip(
                            message: 'Reprendre le dernier point de prix',
                            child: OutlinedButton(
                              onPressed: () => setState(() {
                                _rateCtrl.text =
                                    _price.last.toStringAsFixed(4);
                              }),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Raison affichée aux utilisateurs',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn.staggered(
              index: 5,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Appliquer le nouveau cours'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Axe vertical de la série sélectionnée ─────────────────────────────────────

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({
    required this.axisMax,
    required this.isPrice,
    required this.color,
  });

  final double axisMax;
  final bool isPrice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final steps = [axisMax, axisMax * 0.75, axisMax * 0.5, axisMax * 0.25, 0.0];
    return SizedBox(
      width: 46,
      child: Padding(
        padding: const EdgeInsets.only(
          top: _EditableChartPainter.topPadding - 6,
          bottom: _EditableChartPainter.bottomPadding - 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.map((value) {
            final text = isPrice
                ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1).replaceAll('.', ',')} €'
                : value.toStringAsFixed(0);
            return Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Peintre du graphique éditable ─────────────────────────────────────────────

class _EditableChartPainter extends CustomPainter {
  _EditableChartPainter({
    required this.demand,
    required this.supply,
    required this.price,
    required this.volumeAxisMax,
    required this.priceAxisMax,
    required this.series,
    required this.accent,
    required this.surface,
    required this.gridColor,
    required this.labelColor,
    required this.dragIndex,
  });

  static const double topPadding = 22;
  static const double bottomPadding = 6;

  final List<double> demand;
  final List<double> supply;
  final List<double> price;
  final double volumeAxisMax;
  final double priceAxisMax;
  final _Series series;
  final Color accent;
  final Color surface;
  final Color gridColor;
  final Color labelColor;
  final int? dragIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartBottom = size.height - bottomPadding;
    final groupWidth = size.width / CurrencyRate.chartPointCount;
    final barWidth = groupWidth * 0.26;
    const barGap = 3.0;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Colonne active en surbrillance
    if (dragIndex != null) {
      canvas.drawRect(
        Rect.fromLTWH(groupWidth * dragIndex!, 0, groupWidth, size.height),
        Paint()..color = accent.withValues(alpha: 0.06),
      );
    }

    final demandActive = series == _Series.demand;
    final supplyActive = series == _Series.supply;
    final priceActive = series == _Series.price;

    final demandPaint = Paint()
      ..color = AppTheme.negative
          .withValues(alpha: demandActive ? 0.95 : 0.25);
    final supplyPaint = Paint()
      ..color =
          AppTheme.positive.withValues(alpha: supplyActive ? 0.95 : 0.25);
    final linePaint = Paint()
      ..color = accent.withValues(alpha: priceActive ? 1.0 : 0.3)
      ..strokeWidth = priceActive ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final lineHalo = Paint()
      ..color = surface
      ..strokeWidth = priceActive ? 6.0 : 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    final handleCenters = <Offset>[];

    for (var i = 0; i < CurrencyRate.chartPointCount; i++) {
      final centerX = groupWidth * i + groupWidth / 2;

      final demandHeight =
          (demand[i] / volumeAxisMax).clamp(0.0, 1.0) * chartHeight;
      final supplyHeight =
          (supply[i] / volumeAxisMax).clamp(0.0, 1.0) * chartHeight;

      final demandTop = chartBottom - demandHeight;
      final supplyTop = chartBottom - supplyHeight;

      if (demandHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              centerX - barWidth - barGap / 2,
              demandTop,
              barWidth,
              demandHeight,
            ),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          demandPaint,
        );
      }
      if (supplyHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              centerX + barGap / 2,
              supplyTop,
              barWidth,
              supplyHeight,
            ),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          supplyPaint,
        );
      }

      final priceY = chartBottom -
          (price[i] / priceAxisMax).clamp(0.0, 1.0) * chartHeight;
      if (i == 0) {
        linePath.moveTo(centerX, priceY);
      } else {
        linePath.lineTo(centerX, priceY);
      }

      // Poignées de la série active
      handleCenters.add(switch (series) {
        _Series.demand =>
          Offset(centerX - barGap / 2 - barWidth / 2, demandTop),
        _Series.supply =>
          Offset(centerX + barGap / 2 + barWidth / 2, supplyTop),
        _Series.price => Offset(centerX, priceY),
      });
    }

    canvas.drawPath(linePath, lineHalo);
    canvas.drawPath(linePath, linePaint);

    // Poignées
    final activeColor = switch (series) {
      _Series.demand => AppTheme.negative,
      _Series.supply => AppTheme.positive,
      _Series.price => accent,
    };
    final handleFill = Paint()..color = activeColor;
    final handleStroke = Paint()
      ..color = surface
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < handleCenters.length; i++) {
      final radius = i == dragIndex ? 7.5 : 5.0;
      canvas.drawCircle(handleCenters[i], radius, handleFill);
      canvas.drawCircle(handleCenters[i], radius, handleStroke);
    }

    // Valeur en cours d'édition
    if (dragIndex != null) {
      final i = dragIndex!;
      final value = switch (series) {
        _Series.demand => demand[i],
        _Series.supply => supply[i],
        _Series.price => price[i],
      };
      final text = series == _Series.price
          ? '${value.toStringAsFixed(1).replaceAll('.', ',')} €'
          : value.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: activeColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = handleCenters[i];
      final dx = (anchor.dx - tp.width / 2)
          .clamp(2.0, size.width - tp.width - 2.0);
      final dy = math.max(2.0, anchor.dy - tp.height - 12);
      // Fond pour la lisibilité
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 5, dy - 3, tp.width + 10, tp.height + 6),
        const Radius.circular(7),
      );
      canvas.drawRRect(bgRect, Paint()..color = surface.withValues(alpha: 0.92));
      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = activeColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke,
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _EditableChartPainter oldDelegate) => true;
}
