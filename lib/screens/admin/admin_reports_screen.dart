import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/ban_dialog.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/grouped_report.dart';
import '../../providers/admin_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/file_export/file_export.dart';

/// Signalements remontés par les élèves, regroupés par message.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  // Sans locale : ces formats sont purement numériques, et `intl` exige un
  // initializeDateFormatting() préalable dès qu'on en précise une.
  static final _dateFmt = DateFormat('dd/MM/yyyy à HH:mm');
  static final _stampFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  bool _pendingOnly = true;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupedReportsProvider);
    final actionState = ref.watch(reportActionsProvider);

    return LoadingOverlay(
      isLoading: actionState.isLoading || _exporting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Signalements'),
          actions: [
            // Libellé plutôt qu'une icône seule : l'état du filtre n'était
            // pas lisible, et le bouton passait pour inopérant tant que tous
            // les signalements étaient en attente.
            TextButton(
              onPressed: () => setState(() => _pendingOnly = !_pendingOnly),
              child: Text(
                _pendingOnly ? 'En attente' : 'Tous',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: groupsAsync.when(
          loading: () => const InlineLoader(message: 'Chargement...'),
          error: (e, _) => ErrorRetry(
            message: 'Impossible de charger les signalements',
            onRetry: () => ref.invalidate(groupedReportsProvider),
          ),
          data: (groups) {
            final visible =
                _pendingOnly ? groups.where((g) => g.isPending).toList() : groups;

            if (visible.isEmpty) {
              return EmptyState(
                icon: Icons.verified_user_rounded,
                title: _pendingOnly
                    ? 'Aucun signalement en attente'
                    : 'Aucun signalement',
                subtitle: _pendingOnly
                    ? 'Les nouveaux signalements apparaîtront ici'
                    : 'Rien n\'a encore été signalé',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(groupedReportsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: visible.length,
                itemBuilder: (context, i) => FadeSlideIn.staggered(
                  key: ValueKey('${visible[i].messageId}-${visible[i].reportedId}'),
                  index: i,
                  child: _GroupCard(
                    group: visible[i],
                    dateFmt: _dateFmt,
                    // Récidive : un premier écart et un cinquième n'appellent
                    // pas la même réponse.
                    confirmed: ref
                            .watch(confirmedReportsProvider(
                              visible[i].reportedId,
                            ))
                            .valueOrNull ??
                        0,
                    onReview: (status) => _review(visible[i], status),
                    onBan: () => _ban(visible[i]),
                    onExport: () => _export(visible[i]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _review(GroupedReport group, String status) async {
    try {
      await ref
          .read(reportActionsProvider.notifier)
          .setStatusMany(group.reportIds, status);
      ref.invalidate(groupedReportsProvider);
      if (mounted) {
        AppFeedback.success(
          context,
          status == 'reviewed' ? 'Signalement traité.' : 'Signalement écarté.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    }
  }

  Future<void> _ban(GroupedReport group) async {
    final request = await showBanDialog(
      context,
      group.reportedUsername,
      initialReason: 'Message inapproprié signalé',
    );
    if (request == null) return;

    try {
      await ref.read(adminActionsProvider.notifier).banUserTemp(
            group.reportedId,
            reason: request.reason,
            minutes: request.minutes,
          );
      // Suspendre vaut traitement : le signalement quitte la file d'attente.
      await ref
          .read(reportActionsProvider.notifier)
          .setStatusMany(group.reportIds, 'reviewed');
      ref.invalidate(groupedReportsProvider);
      if (mounted) AppFeedback.success(context, 'Compte suspendu.');
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    }
  }

  /// Construit puis enregistre la transcription complète du chat d'origine.
  Future<void> _export(GroupedReport group) async {
    setState(() => _exporting = true);
    try {
      final lines =
          await ref.read(chatTranscriptProvider(group.classId).future);

      // Tirets simples et non cadratins : ces derniers ressortent souvent en
      // caractere inconnu dans les lecteurs de texte basiques.
      final buffer = StringBuffer()
        ..writeln('SES Coin - discussion')
        ..writeln(
          group.isClassChat ? 'Chat de classe' : 'Chat des annonces',
        )
        ..writeln('Export du ${_stampFmt.format(DateTime.now())}')
        ..writeln('Signalement visant @${group.reportedUsername}')
        ..writeln('${lines.length} message(s)')
        ..writeln('${'=' * 60}\n');

      for (final line in lines) {
        final stamp = _stampFmt.format(line.createdAt.toLocal());
        buffer.writeln('[$stamp] @${line.username} (${line.displayName})');

        if (line.isDeleted) {
          buffer.writeln('  [SUPPRIMÉ PAR SON AUTEUR]');
        }
        if (line.isCensored) {
          buffer.writeln('  [CENSURÉ AUTOMATIQUEMENT]');
        }

        // Un message modifié est restitué dans ses deux versions : c'est
        // souvent l'original qui a motivé le signalement.
        if (line.originalContent != null) {
          buffer.writeln('  [MODIFIÉ'
              '${line.editedAt != null ? ' le ${_stampFmt.format(line.editedAt!.toLocal())}' : ''}]');
          buffer.writeln('  Version d\'origine : ${line.originalContent}');
          buffer.writeln('  Version actuelle  : ${line.content}');
        } else {
          buffer.writeln('  ${line.content}');
        }
        buffer.writeln();
      }

      final name = 'sescoin-discussion-'
          '${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.txt';
      final where = await saveTextFile(name, buffer.toString());

      if (!mounted) return;
      if (where == null) {
        AppFeedback.error(context, 'Export impossible sur cet appareil.');
      } else {
        AppFeedback.success(context, 'Transcription enregistrée ($where).');
      }
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.dateFmt,
    required this.confirmed,
    required this.onReview,
    required this.onBan,
    required this.onExport,
  });

  final GroupedReport group;
  final DateFormat dateFmt;

  /// Signalements déjà retenus contre l'auteur, tous messages confondus.
  final int confirmed;
  final ValueChanged<String> onReview;
  final VoidCallback onBan;
  final VoidCallback onExport;

  /// Plus un message est signalé, plus la pastille tire vers le rouge.
  Color _severityColor() {
    if (group.reportCount >= 5) return AppTheme.negative;
    if (group.reportCount >= 3) return AppTheme.warning;
    return AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = _severityColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severity.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 13, color: severity),
                        const SizedBox(width: 5),
                        Text(
                          '${group.reportCount} signalement'
                          '${group.reportCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: severity,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    group.isClassChat
                        ? Icons.school_rounded
                        : Icons.campaign_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  if (confirmed > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.negative.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'récidive ×$confirmed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.negative,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!group.isPending)
                    Text(
                      'traité',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.messageContent,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              _Line(
                icon: Icons.person_rounded,
                label: 'Auteur',
                color: AppTheme.negative,
                child: InkWell(
                  onTap: () => context.push('/user/${group.reportedUsername}'),
                  child: Text(
                    '@${group.reportedUsername}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Line(
                icon: Icons.flag_outlined,
                label: 'Signalé par',
                color: theme.colorScheme.onSurfaceVariant,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in group.reporters)
                      InkWell(
                        onTap: () => context.push('/user/$r'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '@$r',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Premier signalement ${dateFmt.format(group.firstReportedAt.toLocal())}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 20),
              // Grille de deux colonnes plutôt qu'un Wrap : sur mobile, ce
              // dernier renvoyait les boutons à la ligne sans alignement.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Discussion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (group.isPending) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReview('dismissed'),
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        label: const Text('Sans suite'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (group.isPending) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReview('reviewed'),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Retenu'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.positive,
                          side: BorderSide(
                            color: AppTheme.positive.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onBan,
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: const Text('Suspendre'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.negative,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
