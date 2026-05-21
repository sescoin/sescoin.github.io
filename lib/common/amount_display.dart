import 'package:flutter/material.dart';

import '../../core/theme.dart';

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.amount,
    this.isPositive,
    this.fontSize = 16,
    this.showSign = false,
    this.showSymbol = true,
    this.fontWeight = FontWeight.w700,
  });

  final double amount;
  final bool? isPositive; // null = neutre (pas de couleur)
  final double fontSize;
  final bool showSign;
  final bool showSymbol;
  final FontWeight fontWeight;

  String get _formatted {
    final abs = amount.abs();
    final sign = showSign ? (amount >= 0 ? '+' : '-') : '';
    final num = abs.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    final symbol = showSymbol ? ' SC' : '';
    return '$sign$num$symbol';
  }

  Color? _color(BuildContext context) {
    if (isPositive == null) return null;
    return isPositive! ? AppTheme.positive : AppTheme.negative;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: _color(context) ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
