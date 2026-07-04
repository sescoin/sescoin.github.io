import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/ban_guard.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../home/balance_card.dart';
import '../../home/currency_chart.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/nfc_hce_service.dart';
import '../../transaction/transaction_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _nfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    if (!NfcHceService.isSupported) {
      return;
    }
    try {
      final state = await NfcHceService.getNfcState();
      if (mounted) {
        setState(() => _nfcAvailable = state == 'enabled');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final recentAsync = ref.watch(recentTransactionsProvider);
    final unreadAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SES Coin'),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () =>
                    context.go('${AppRoutes.profile}?tab=notifications'),
                icon: const Icon(Icons.notifications_outlined),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedBadge(
                  count: unreadAsync.valueOrNull ?? 0,
                  color: AppTheme.negative,
                ),
              ),
            ],
          ),
          if (profile?.isAdmin == true) _AdminButton(),
        ],
      ),
      body: RefreshIndicator(
        color: context.accent,
        onRefresh: () async {
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(currentRateProvider);
          await ref.read(currentProfileProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BannedBanner(),
              FadeSlideIn.staggered(index: 0, child: const BalanceCard()),
              const SizedBox(height: 24),
              FadeSlideIn.staggered(index: 1, child: const CurrencyChart()),
              const SizedBox(height: 24),
              if (_nfcAvailable) ...[
                FadeSlideIn.staggered(
                  index: 2,
                  child: PressableScale(
                    onTap: () => context.go(AppRoutes.pay),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.accent.withValues(alpha: 0.15),
                            context.accent.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.nfc_rounded,
                            color: context.accent,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Paiement NFC',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Mode principal · approche les téléphones',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: context.accent.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FadeSlideIn.staggered(
                index: 3,
                child: Text(
                  'Actions rapides',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn.staggered(
                index: 4,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickAction(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Payer',
                      onTap: () => context.go(AppRoutes.pay),
                    ),
                    _QuickAction(
                      icon: Icons.send_rounded,
                      label: 'Transférer',
                      onTap: () => context.push(AppRoutes.transferManual),
                    ),
                    _QuickAction(
                      icon: Icons.leaderboard_rounded,
                      label: 'Classement',
                      onTap: () => context.push(AppRoutes.leaderboard),
                    ),
                    _QuickAction(
                      icon: Icons.handshake_rounded,
                      label: 'Prêts',
                      onTap: () => context.push(AppRoutes.loanCreate),
                    ),
                    _QuickAction(
                      icon: Icons.hub_rounded,
                      label: 'Blockchain',
                      onTap: () => context.push(AppRoutes.transactionExplorer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn.staggered(
                index: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dernières transactions',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.wallet),
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn.staggered(
                index: 6,
                child: recentAsync.when(
                  data: (txs) => txs.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Aucune transaction',
                          subtitle: 'Tes transactions apparaîtront ici',
                        )
                      : Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: txs.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 16,
                            ),
                            itemBuilder: (context, i) => TransactionTile(
                              transaction: txs[i],
                            ),
                          ),
                        ),
                  loading: () => const InlineLoader(),
                  error: (e, _) => ErrorRetry(
                    message: 'Impossible de charger les transactions',
                    onRetry: () => ref.invalidate(recentTransactionsProvider),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 56) / 3;
    return SizedBox(
      width: width.clamp(92, 180).toDouble(),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: context.accent, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends ConsumerState<_AdminButton>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pendingRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(pendingRequestsProvider).valueOrNull?.length ?? 0;

    return Stack(
      children: [
        IconButton(
          onPressed: () async {
            await GoRouter.of(context).push(AppRoutes.adminDashboard);
            ref.invalidate(pendingRequestsProvider);
          },
          icon: const Icon(Icons.admin_panel_settings_rounded),
          tooltip: 'Administration',
        ),
        Positioned(
          right: 6,
          top: 6,
          child: AnimatedBadge(
            count: count,
            color: AppTheme.warning,
            size: 17,
          ),
        ),
      ],
    );
  }
}
