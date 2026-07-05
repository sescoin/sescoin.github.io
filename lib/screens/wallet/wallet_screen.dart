import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../transaction/transaction_tile.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(walletProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille'),
        actions: [
          IconButton(
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isRefreshing && state.items.isEmpty) {
            return const InlineLoader(message: 'Chargement...');
          }

          if (state.error != null && state.items.isEmpty) {
            return ErrorRetry(
              message: 'Impossible de charger les transactions',
              onRetry: () => ref.read(walletProvider.notifier).loadInitial(),
            );
          }

          if (!state.isRefreshing && state.items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Aucune transaction',
              subtitle: 'Les transactions apparaîtront ici',
            );
          }

          // 0 = en-tête solde, puis séparateurs + tuiles.
          return RefreshIndicator(
            color: context.accent,
            onRefresh: () => ref.read(walletProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              // Pré-construit les tuiles hors écran pour un défilement fluide.
              scrollCacheExtent: const ScrollCacheExtent.pixels(800),
              itemCount: state.items.length + 1 + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, i) => i == 0
                  ? const SizedBox.shrink()
                  : const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const _BalanceHeader();
                }
                final index = i - 1;
                if (index == state.items.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                // Pas d'animation d'apparition sur les tuiles recyclées :
                // rejouer la cascade à chaque défilement saccade la liste.
                return TransactionTile(transaction: state.items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── En-tête : solde courant ────────────────────────────────────────────────────

class _BalanceHeader extends ConsumerWidget {
  const _BalanceHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.accent;
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: FadeSlideIn(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1A2E),
                Color.lerp(const Color(0xFF16213E), accent, 0.28)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solde disponible',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  CountUpAmount(
                    value: profile?.balance ?? 0,
                    builder: (context, animated) => Text(
                      '${animated.toStringAsFixed(2)} SC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
