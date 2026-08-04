import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/dispose_scope.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../providers/admin_provider.dart';
import '../../providers/report_provider.dart';

/// Signalements remontés par les élèves depuis le chat.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  static final _dateFmt = DateFormat('dd/MM/yyyy à HH:mm', 'fr');

  bool _pendingOnly = true;

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsProvider);
    final actionState = ref.watch(reportActionsProvider);

    return LoadingOverlay(
      isLoading: actionState.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Signalements'),
          actions: [
            IconButton(
              tooltip: _pendingOnly
                  ? 'Voir tous les signalements'
                  : 'Voir les signalements en attente',
              icon: Icon(
                _pendingOnly
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_off_rounded,
              ),
              onPressed: () => setState(() => _pendingOnly = !_pendingOnly),
            ),
          ],
        ),
        body: reportsAsync.when(
          loading: () => const InlineLoader(message: 'Chargement...'),
          error: (e, _) => ErrorRetry(
            message: 'Impossible de charger les signalements',
            onRetry: () => ref.invalidate(reportsProvider),
          ),
          data: (reports) {
            final visible =
                _pendingOnly ? reports.where((r) => r.isPending).toList() : reports;

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

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: visible.length,
              itemBuilder: (context, i) => FadeSlideIn.staggered(
                key: ValueKey(visible[i].id),
                index: i,
                child: _ReportCard(
                  report: visible[i],
                  dateFmt: _dateFmt,
                  onReview: (status) => _setStatus(visible[i], status),
                  onBan: () => _ban(visible[i]),
                  onDelete: () => _delete(visible[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _setStatus(Report report, String status) async {
    try {
      await ref.read(reportActionsProvider.notifier).setStatus(report.id, status);
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

  Future<void> _delete(Report report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        tone: AppDialogTone.danger,
        title: 'Supprimer ce signalement ?',
        content: const Text('Il disparaîtra définitivement de la liste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(reportActionsProvider.notifier).delete(report.id);
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    }
  }

  /// Bannit l'auteur du message et marque le signalement comme traité.
  Future<void> _ban(Report report) async {
    final reasonCtrl = TextEditingController(
      text: 'Message inapproprié signalé',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [reasonCtrl],
        child: AppDialog(
          icon: Icons.block_rounded,
          tone: AppDialogTone.danger,
          title: 'Bannir @${report.reportedUsername} ?',
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Motif'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bannir'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonCtrl.text.trim();
    if (confirmed != true) return;

    try {
      await ref.read(adminActionsProvider.notifier).banUser(
            report.reportedId,
            reason: reason.isEmpty ? null : reason,
          );
      await ref
          .read(reportActionsProvider.notifier)
          .setStatus(report.id, 'reviewed');
      if (mounted) AppFeedback.success(context, 'Compte banni.');
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.dateFmt,
    required this.onReview,
    required this.onBan,
    required this.onDelete,
  });

  final Report report;
  final DateFormat dateFmt;
  final ValueChanged<String> onReview;
  final VoidCallback onBan;
  final VoidCallback onDelete;

  (String, Color) get _statusLabel => switch (report.status) {
        'reviewed' => ('Traité', AppTheme.positive),
        'dismissed' => ('Écarté', Colors.grey),
        _ => ('En attente', AppTheme.warning),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusLabel;

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
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    report.isClassChat
                        ? Icons.school_rounded
                        : Icons.campaign_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  Text(
                    dateFmt.format(report.createdAt.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contenu au moment du signalement : le message d'origine peut
              // avoir été modifié ou supprimé depuis.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.messageContent,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              _Line(
                icon: Icons.person_rounded,
                label: 'Auteur',
                value: '@${report.reportedUsername}',
                color: AppTheme.negative,
                onTap: () => context.push('/user/${report.reportedUsername}'),
              ),
              const SizedBox(height: 3),
              _Line(
                icon: Icons.flag_outlined,
                label: 'Signalé par',
                value: '@${report.reporterUsername}',
                color: theme.colorScheme.onSurfaceVariant,
                onTap: () => context.push('/user/${report.reporterUsername}'),
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (report.isPending) ...[
                    TextButton.icon(
                      onPressed: () => onReview('dismissed'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Écarter'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onReview('reviewed'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Traité'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.positive,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onBan,
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('Bannir'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.negative,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ] else
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.negative,
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

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            SizedBox(
              width: 86,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
