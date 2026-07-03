import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/animations.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/currency_provider.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  String _format(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final rateAsync = ref.watch(currentRateProvider);
    final accent = context.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            Color.lerp(const Color(0xFF16213E), accent, 0.12)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mon solde',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              rateAsync.when(
                data: (rate) => _RateBadge(rate: rate),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          profileAsync.when(
            data: (profile) => profile == null
                ? const Text(
                    '— SC',
                    style: TextStyle(color: Colors.white54, fontSize: 36),
                  )
                : CountUpAmount(
                    value: profile.balance,
                    builder: (context, animated) => Text(
                      '${_format(animated)} SC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
            loading: () => const Text(
              '— SC',
              style: TextStyle(color: Colors.white54, fontSize: 36),
            ),
            error: (_, __) => const Text(
              'Erreur',
              style: TextStyle(color: Colors.redAccent, fontSize: 24),
            ),
          ),
          const SizedBox(height: 16),
          profileAsync.when(
            data: (profile) => profile == null
                ? const SizedBox.shrink()
                : Text(
                    '@${profile.username}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  const _RateBadge({required this.rate});

  final dynamic rate;

  @override
  Widget build(BuildContext context) {
    final pricePoints = (rate.pricePoints as List<double>);
    final first = pricePoints.isEmpty ? rate.rate as double : pricePoints.first;
    final last = pricePoints.isEmpty ? rate.rate as double : pricePoints.last;
    final changePercent = first == 0 ? 0.0 : ((last - first) / first) * 100;
    final isUp = changePercent > 0;
    final isDown = changePercent < 0;
    final color = isUp
        ? AppTheme.positive
        : isDown
            ? AppTheme.negative
            : Colors.white54;
    final icon = isUp
        ? Icons.trending_up_rounded
        : isDown
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final sign = isUp ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$sign${changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
