import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/animations.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/sanction.dart';
import '../../providers/report_provider.dart';

/// Historique des mesures prises contre les comptes.
///
/// Les sanctions automatiques (filtre, seuils) y figurent au même titre que
/// celles décidées par l'administrateur : c'est le seul endroit où l'on peut
/// reconstituer ce qui est arrivé à un compte.
class AdminSanctionsScreen extends ConsumerWidget {
  const AdminSanctionsScreen({super.key});

  // Sans locale : le format est purement numérique, et `intl` exige un
  // initializeDateFormatting() préalable dès qu'on en précise une.
  static final _dateFmt = DateFormat('dd/MM/yyyy à HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sanctionsAsync = ref.watch(sanctionsProvider);

    return LoadingOverlay(
      isLoading: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Journal des sanctions')),
        body: sanctionsAsync.when(
          loading: () => const InlineLoader(message: 'Chargement...'),
          error: (e, _) => ErrorRetry(
            message: 'Impossible de charger le journal',
            onRetry: () => ref.invalidate(sanctionsProvider),
          ),
          data: (sanctions) {
            if (sanctions.isEmpty) {
              return const EmptyState(
                icon: Icons.gavel_rounded,
                title: 'Aucune sanction',
                subtitle: 'Les mesures prises apparaîtront ici',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: sanctions.length,
              itemBuilder: (context, i) => FadeSlideIn.staggered(
                key: ValueKey(sanctions[i].id),
                index: i,
                child: _SanctionCard(
                  sanction: sanctions[i],
                  dateFmt: _dateFmt,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SanctionCard extends StatelessWidget {
  const _SanctionCard({required this.sanction, required this.dateFmt});

  final Sanction sanction;
  final DateFormat dateFmt;

  (IconData, Color) get _visual => switch (sanction.kind) {
        'ban' => (Icons.block_rounded, AppTheme.negative),
        'mute' => (Icons.volume_off_rounded, AppTheme.warning),
        _ => (Icons.warning_amber_rounded, AppTheme.info),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _visual;
    final active = sanction.isActive;
    final lifted = sanction.liftedAt != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sanction.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 7),
                        // La levée se lit sur la sanction elle-même : un
                        // épisode terminé ne mérite pas une seconde entrée.
                        if (active)
                          _StatusChip(label: 'en cours', color: color)
                        else if (lifted)
                          const _StatusChip(
                            label: 'levée',
                            color: AppTheme.positive,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () => context.push('/user/${sanction.username}'),
                      child: Text(
                        '@${sanction.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (sanction.reason != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        sanction.reason!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text: dateFmt.format(sanction.createdAt.toLocal()),
                        ),
                        if (lifted)
                          _Meta(
                            icon: Icons.lock_open_rounded,
                            text: 'levée le '
                                '${dateFmt.format(sanction.liftedAt!.toLocal())}',
                          )
                        else if (sanction.until != null)
                          _Meta(
                            icon: Icons.event_busy_rounded,
                            text: 'jusqu\'au '
                                '${dateFmt.format(sanction.until!.toLocal())}',
                          ),
                        _Meta(
                          icon: sanction.automatic
                              ? Icons.smart_toy_rounded
                              : Icons.person_rounded,
                          text: sanction.automatic
                              ? 'automatique'
                              : '@${sanction.issuedByUsername ?? 'admin'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
