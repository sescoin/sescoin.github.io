import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../../providers/settings_provider.dart';
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
        title: const _BrandTitle(),
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
                      icon: Icons.handshake_rounded,
                      label: 'Prêts',
                      onTap: () => context.push(AppRoutes.loanCreate),
                    ),
                    _QuickAction(
                      icon: Icons.people_alt_rounded,
                      label: 'Comptes',
                      onTap: () => context.push(AppRoutes.accounts),
                    ),
                    _QuickAction(
                      icon: Icons.leaderboard_rounded,
                      label: 'Classement',
                      onTap: () => context.push(AppRoutes.leaderboard),
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
                          subtitle: 'Les transactions apparaîtront ici',
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
    final accent = context.accent;
    final width = (MediaQuery.of(context).size.width - 56) / 3;
    return SizedBox(
      width: width.clamp(92, 180).toDouble(),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.18 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.20),
                      accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
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

// ── Titre de marque animé (« SES Coin ») ──────────────────────────────────────

class _BrandTitle extends ConsumerStatefulWidget {
  const _BrandTitle();

  @override
  ConsumerState<_BrandTitle> createState() => _BrandTitleState();
}

class _BrandTitleState extends ConsumerState<_BrandTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    // Le balayage lumineux repose sur un ShaderMask. Le compiler pendant la
    // construction de l'accueil provoque une saccade brève au tout premier
    // affichage : on laisse la page se poser avant de démarrer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || AppMotion.reduce) return;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _controller.repeat();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le réglage peut basculer alors que l'écran est déjà monté : le lire au
    // seul initState laissait le balayage tourner jusqu'au prochain
    // redémarrage de l'application.
    final reduce = ref.watch(settingsProvider.select((s) => s.reduceMotion));
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    final accent = context.accent;
    final base = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'S',
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.onAccent(accent),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 9),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Texte nu tant que l'animation n'a pas démarré (aucun shader
            // compilé au premier affichage) et lorsque les animations sont
            // réduites.
            if (reduce || !_controller.isAnimating) return child!;
            // Bande lumineuse d'accent qui balaie le texte.
            final dx = -1.6 + 3.2 * _controller.value;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment(dx - 0.35, 0),
                end: Alignment(dx + 0.35, 0),
                colors: [base, accent, base],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(rect),
              child: child,
            );
          },
          child: Text(
            'SES Coin',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
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
