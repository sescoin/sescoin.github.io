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

/// Entrée du panneau d'administration.
///
/// Le panneau et sa réplique dans le tutoriel se construisent tous deux
/// depuis [adminMenu] : ils ne peuvent pas diverger.
class AdminMenuEntry {
  const AdminMenuEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.color,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  /// null = couleur d'accent du thème.
  final Color? color;
}

class AdminMenuSection {
  const AdminMenuSection({
    required this.icon,
    required this.title,
    required this.entries,
  });

  final IconData icon;
  final String title;
  final List<AdminMenuEntry> entries;
}

const adminMenu = <AdminMenuSection>[
  AdminMenuSection(
    icon: Icons.people_rounded,
    title: 'Comptes',
    entries: [
      AdminMenuEntry(
        id: 'accounts',
        icon: Icons.people_rounded,
        title: 'Tous les comptes',
        subtitle: 'Voir, bannir, créditer, débiter, supprimer ou '
            'réinitialiser le mot de passe',
        route: AppRoutes.adminAccounts,
      ),
      AdminMenuEntry(
        id: 'reports',
        icon: Icons.flag_rounded,
        title: 'Signalements',
        subtitle: 'Messages remontés par les utilisateurs',
        route: AppRoutes.adminReports,
        color: AppTheme.warning,
      ),
      AdminMenuEntry(
        id: 'sanctions',
        icon: Icons.gavel_rounded,
        title: 'Journal des sanctions',
        subtitle: 'Mesures automatiques et décisions prises',
        route: AppRoutes.adminSanctions,
        color: AppTheme.info,
      ),
      AdminMenuEntry(
        id: 'requests',
        icon: Icons.mark_email_unread_rounded,
        title: 'Demandes de compte',
        subtitle: 'Approuver ou refuser les demandes',
        route: AppRoutes.adminRequests,
      ),
    ],
  ),
  AdminMenuSection(
    icon: Icons.storefront_rounded,
    title: 'Marché',
    entries: [
      AdminMenuEntry(
        id: 'market',
        icon: Icons.storefront_rounded,
        title: 'Gérer le marché',
        subtitle: 'Créer, modifier ou supprimer des offres et enchères',
        route: AppRoutes.adminMarketEdit,
      ),
    ],
  ),
  AdminMenuSection(
    icon: Icons.school_rounded,
    title: 'Classes',
    entries: [
      AdminMenuEntry(
        id: 'classes',
        icon: Icons.school_rounded,
        title: 'Gérer les classes',
        subtitle: 'Créer, renommer, supprimer, gérer les membres',
        route: AppRoutes.adminClasses,
      ),
    ],
  ),
  AdminMenuSection(
    icon: Icons.account_balance_rounded,
    title: 'Prêts',
    entries: [
      AdminMenuEntry(
        id: 'loans',
        icon: Icons.account_balance_rounded,
        title: 'Prêts',
        subtitle: 'Liste de tous les prêts et paramètres',
        route: AppRoutes.adminLoans,
        color: AppTheme.info,
      ),
    ],
  ),
  AdminMenuSection(
    icon: Icons.query_stats_rounded,
    title: 'Économie',
    entries: [
      AdminMenuEntry(
        id: 'tax',
        icon: Icons.percent_rounded,
        title: 'Taxer tout le monde',
        subtitle: 'Prélever un pourcentage sur tous les comptes',
        route: AppRoutes.adminTax,
        color: AppTheme.negative,
      ),
      AdminMenuEntry(
        id: 'reward',
        icon: Icons.card_giftcard_rounded,
        title: 'Distribuer une récompense',
        subtitle: 'Créditer tous les comptes en une fois',
        route: AppRoutes.adminReward,
        color: AppTheme.positive,
      ),
      AdminMenuEntry(
        id: 'rate',
        icon: Icons.trending_up_rounded,
        title: 'Modifier le cours',
        subtitle: "Éditer la demande, l'offre et le prix",
        route: AppRoutes.adminRate,
      ),
    ],
  ),
  AdminMenuSection(
    icon: Icons.help_outline_rounded,
    title: 'Aide',
    entries: [
      AdminMenuEntry(
        id: 'tutorial',
        icon: Icons.play_lesson_rounded,
        title: 'Tutoriel',
        subtitle: 'Découvrir pas à pas toutes les fonctions de l\'application',
        route: AppRoutes.adminTutorial,
      ),
    ],
  ),
];

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminActionsProvider);
    final badges = {
      'reports': ref.watch(pendingReportsCountProvider),
      'requests': ref.watch(pendingRequestsProvider).valueOrNull?.length ?? 0,
    };

    var index = 0;
    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            FadeSlideIn.staggered(
              index: 0,
              child: AdminHeaderCard(
                name: ref.watch(currentProfileProvider).value?.displayName ??
                    '',
              ),
            ),
            for (final section in adminMenu) ...[
              const SizedBox(height: 18),
              AdminSectionTitle(icon: section.icon, title: section.title),
              for (final entry in section.entries)
                AdminTile(
                  index: ++index,
                  entry: entry,
                  badgeCount: badges[entry.id] ?? 0,
                  onTap: () => context.push(entry.route),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── En-tête ────────────────────────────────────────────────────────────────────

class AdminHeaderCard extends StatelessWidget {
  const AdminHeaderCard({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Container(
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
                  name,
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
    );
  }
}

// ── Titre de section ───────────────────────────────────────────────────────────

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle({super.key, required this.icon, required this.title});

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

class AdminTile extends StatelessWidget {
  const AdminTile({
    super.key,
    required this.index,
    required this.entry,
    required this.onTap,
    this.badgeCount = 0,
  });

  final int index;
  final AdminMenuEntry entry;
  final VoidCallback onTap;

  /// > 0 : petit compteur affiché à côté du titre.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = entry.color ?? theme.colorScheme.primary;

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
                    child: Icon(entry.icon, color: tileColor, size: 21),
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
                                entry.title,
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
                          entry.subtitle,
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
