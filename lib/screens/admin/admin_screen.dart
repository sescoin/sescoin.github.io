import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingRequestsProvider);
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppTheme.gold,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Administrateur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ref.watch(currentProfileProvider).value?.displayName ??
                            '',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            pendingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (requests) => requests.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_rounded,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${requests.length} demande${requests.length > 1 ? 's' : ''} en attente',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push(AppRoutes.adminRequests),
                            child: const Text('Voir'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Comptes'),
            _AdminTile(
              icon: Icons.people_rounded,
              title: 'Tous les comptes',
              subtitle: 'Voir, bannir, créditer, débiter ou supprimer',
              onTap: () => context.push(AppRoutes.adminAccounts),
            ),
            _AdminTile(
              icon: Icons.mark_email_unread_rounded,
              title: 'Demandes de compte',
              subtitle: 'Approuvez ou refusez les demandes',
              onTap: () => context.push(AppRoutes.adminRequests),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Marché'),
            _AdminTile(
              icon: Icons.storefront_rounded,
              title: 'Gérer le marché',
              subtitle: 'Créez, modifiez ou supprimez des offres et enchères',
              onTap: () => context.push(AppRoutes.adminMarketEdit),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Classes'),
            _AdminTile(
              icon: Icons.school_rounded,
              title: 'Gérer les classes',
              subtitle: 'Créer, renommer, supprimer, gérer les membres',
              onTap: () => context.push(AppRoutes.adminClasses),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Économie'),
            _AdminTile(
              icon: Icons.percent_rounded,
              title: 'Taxer tout le monde',
              subtitle: 'Prélevez un pourcentage sur tous les comptes',
              onTap: () => context.push(AppRoutes.adminTax),
              color: AppTheme.negative,
            ),
            _AdminTile(
              icon: Icons.card_giftcard_rounded,
              title: 'Distribuer une récompense',
              subtitle: 'Créditez tous les comptes depuis une vraie interface',
              onTap: () => context.push(AppRoutes.adminReward),
              color: AppTheme.positive,
            ),
            _AdminTile(
              icon: Icons.trending_up_rounded,
              title: 'Modifier le cours',
              subtitle: "Éditez la demande, l'offre et le prix",
              onTap: () => context.push(AppRoutes.adminRate),
              color: AppTheme.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppTheme.gold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  final Color _defaultColor = AppTheme.gold;

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? _defaultColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tileColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tileColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
