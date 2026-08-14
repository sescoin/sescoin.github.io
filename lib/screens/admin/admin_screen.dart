import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRequestsProvider);
    final state = ref.watch(adminActionsProvider);
    final accent = context.accent;

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            FadeSlideIn.staggered(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A1A2E),
                      Color.lerp(const Color(0xFF16213E), accent, 0.22)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mode Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ref
                                    .watch(currentProfileProvider)
                                    .value
                                    ?.displayName ??
                                '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Text(
                        'Contrôle total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── Sections ────────────────────────────────────────────────────
            const _SectionTitle(icon: Icons.people_rounded, title: 'Comptes'),
            _AdminTile(
              index: 1,
              icon: Icons.people_rounded,
              title: 'Tous les comptes',
              subtitle: 'Voir, bannir, créditer, débiter, supprimer ou '
                  'réinitialiser le mot de passe',
              onTap: () => context.push(AppRoutes.adminAccounts),
            ),
            _AdminTile(
              index: 2,
              icon: Icons.flag_rounded,
              title: 'Signalements',
              subtitle: 'Messages remontés par les élèves',
              badgeCount: ref.watch(pendingReportsCountProvider),
              onTap: () => context.push(AppRoutes.adminReports),
              color: AppTheme.warning,
            ),
            _AdminTile(
              index: 2,
              icon: Icons.gavel_rounded,
              title: 'Journal des sanctions',
              subtitle: 'Mesures automatiques et décisions prises',
              onTap: () => context.push(AppRoutes.adminSanctions),
              color: AppTheme.info,
            ),
            _AdminTile(
              index: 2,
              icon: Icons.mark_email_unread_rounded,
              title: 'Demandes de compte',
              subtitle: 'Approuver ou refuser les demandes',
              badgeCount: pendingAsync.valueOrNull?.length ?? 0,
              onTap: () => context.push(AppRoutes.adminRequests),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.storefront_rounded,
              title: 'Marché',
            ),
            _AdminTile(
              index: 3,
              icon: Icons.storefront_rounded,
              title: 'Gérer le marché',
              subtitle: 'Créer, modifier ou supprimer des offres et enchères',
              onTap: () => context.push(AppRoutes.adminMarketEdit),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(icon: Icons.school_rounded, title: 'Classes'),
            _AdminTile(
              index: 4,
              icon: Icons.school_rounded,
              title: 'Gérer les classes',
              subtitle: 'Créer, renommer, supprimer, gérer les membres',
              onTap: () => context.push(AppRoutes.adminClasses),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.account_balance_rounded,
              title: 'Prêts',
            ),
            _AdminTile(
              index: 5,
              icon: Icons.account_balance_rounded,
              title: 'Prêts',
              subtitle: 'Liste de tous les prêts et paramètres',
              onTap: () => context.push(AppRoutes.adminLoans),
              color: AppTheme.info,
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.query_stats_rounded,
              title: 'Économie',
            ),
            _AdminTile(
              index: 6,
              icon: Icons.percent_rounded,
              title: 'Taxer tout le monde',
              subtitle: 'Prélever un pourcentage sur tous les comptes',
              onTap: () => context.push(AppRoutes.adminTax),
              color: AppTheme.negative,
            ),
            _AdminTile(
              index: 7,
              icon: Icons.card_giftcard_rounded,
              title: 'Distribuer une récompense',
              subtitle: 'Créditer tous les comptes en une fois',
              onTap: () => context.push(AppRoutes.adminReward),
              color: AppTheme.positive,
            ),
            _AdminTile(
              index: 8,
              icon: Icons.trending_up_rounded,
              title: 'Modifier le cours',
              subtitle: "Éditer la demande, l'offre et le prix",
              onTap: () => context.push(AppRoutes.adminRate),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Titre de section ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 7),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Tuile d'action ─────────────────────────────────────────────────────────────

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.badgeCount = 0,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// null = couleur d'accent du thème.
  final Color? color;

  /// > 0 : petit compteur affiché à côté du titre.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.primary;

    return FadeSlideIn.staggered(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PressableScale(
          onTap: onTap,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tileColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: tileColor, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            if (badgeCount > 0) ...[
                              const SizedBox(width: 8),
                              AnimatedBadge(
                                count: badgeCount,
                                color: tileColor,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
