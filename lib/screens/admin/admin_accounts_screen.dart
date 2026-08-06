import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/dispose_scope.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class AdminAccountsScreen extends ConsumerStatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  ConsumerState<AdminAccountsScreen> createState() =>
      _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends ConsumerState<AdminAccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Profile> _filter(List<Profile> profiles) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return profiles;
    return profiles
        .where((p) =>
            p.displayName.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final state = ref.watch(adminActionsProvider);
    final currentId = ref.watch(currentUserIdProvider) ?? '';

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tous les comptes')),
        body: profilesAsync.when(
          loading: () => const InlineLoader(),
          error: (error, _) => ErrorRetry(
            message: 'Impossible de charger les comptes',
            onRetry: () => ref.invalidate(allProfilesProvider),
          ),
          data: (profiles) {
            if (profiles.isEmpty) {
              return const EmptyState(
                icon: Icons.people_rounded,
                title: 'Aucun compte',
              );
            }

            final filtered = _filter(profiles);

            return Column(
              children: [
                // ── Recherche + compteur ──────────────────────────────────
                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un compte…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon:
                                    const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} compte${filtered.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Aucun résultat',
                          subtitle: 'Aucun compte pour « $_query »',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _AccountCard(
                            profile: filtered[index],
                            isMe: filtered[index].id == currentId,
                            onTap: () => context
                                .push('/user/${filtered[index].username}'),
                            onAction: (action) => _handleAction(
                              ctx: context,
                              action: action,
                              profile: filtered[index],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction({
    required BuildContext ctx,
    required String action,
    required Profile profile,
  }) async {
    switch (action) {
      case 'credit':
      case 'debit':
        await _adjustBalance(ctx, profile, action == 'debit');
      case 'ban':
        await _ban(ctx, profile.id);
      case 'unban':
        try {
          await ref.read(adminActionsProvider.notifier).unbanUser(profile.id);
          if (ctx.mounted) {
            AppFeedback.success(ctx, 'Compte débanni.');
          }
        } catch (error) {
          if (ctx.mounted) {
            AppFeedback.error(ctx, error);
          }
        }
      case 'reset_password':
        await _resetPassword(ctx, profile);
      case 'delete':
        await _delete(ctx, profile.id, profile.displayName);
    }
  }

  /// Redéfinit le mot de passe d'un compte. Le champ reste en clair : c'est
  /// l'administrateur qui devra transmettre la valeur au titulaire.
  Future<void> _resetPassword(BuildContext ctx, Profile profile) async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => DisposeScope(
        disposables: [passwordCtrl],
        child: AppDialog(
          icon: Icons.key_rounded,
          title: 'Réinitialiser le mot de passe',
          subtitle: '@${profile.username}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: passwordCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  helperText: '8 caractères minimum',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Le nouveau mot de passe devra être communiqué au titulaire '
                'du compte : il ne lui sera pas envoyé.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color:
                      Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );

    final password = passwordCtrl.text;
    if (confirmed != true) return;
    if (password.length < 8) {
      if (ctx.mounted) {
        AppFeedback.warning(
          ctx,
          'Le mot de passe doit contenir au moins 8 caractères.',
        );
      }
      return;
    }
    try {
      await ref
          .read(adminActionsProvider.notifier)
          .resetPassword(profile.id, password);
      if (ctx.mounted) {
        AppFeedback.success(ctx, 'Mot de passe réinitialisé.');
      }
    } catch (error) {
      if (ctx.mounted) {
        AppFeedback.error(ctx, error);
      }
    }
  }

  Future<void> _adjustBalance(
    BuildContext ctx,
    Profile profile,
    bool isDebit,
  ) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDebit ? 'Débiter le compte' : 'Créditer le compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant',
                suffixText: 'SC',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Raison'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).adjustBalance(
            userId: profile.id,
            amount: isDebit ? -amount : amount,
            reason: reasonCtrl.text,
          );
      if (ctx.mounted) {
        AppFeedback.success(
          ctx,
          '${isDebit ? '-' : '+'}${amount.toStringAsFixed(2)} SC appliqué.',
        );
      }
    } catch (error) {
      if (ctx.mounted) {
        AppFeedback.error(ctx, error);
      }
    }
  }

  Future<void> _ban(BuildContext ctx, String userId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bannir le compte'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Raison (optionnelle)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).banUser(
            userId,
            reason: reasonCtrl.text.isEmpty ? null : reasonCtrl.text,
          );
      if (ctx.mounted) {
        AppFeedback.success(ctx, 'Compte banni.');
      }
    } catch (error) {
      if (ctx.mounted) {
        AppFeedback.error(ctx, error);
      }
    }
  }

  Future<void> _delete(
    BuildContext ctx,
    String userId,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
          'Supprimer définitivement le compte de $displayName ?\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).deleteUser(userId);
      if (ctx.mounted) {
        AppFeedback.success(ctx, 'Compte supprimé.');
      }
    } catch (error) {
      if (ctx.mounted) {
        AppFeedback.error(ctx, error);
      }
    }
  }
}

// ── Carte de compte ────────────────────────────────────────────────────────────
// Pas d'animation d'apparition : les tuiles recyclées rejoueraient la cascade
// et saccaderaient le défilement.

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.profile,
    required this.isMe,
    required this.onTap,
    required this.onAction,
  });

  final Profile profile;
  final bool isMe;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                UserAvatar(
                  username: profile.username,
                  avatarUrl: profile.avatarUrl,
                  radius: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            _Badge(label: 'Moi', color: accent),
                          ],
                          if (profile.isBanned) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              label: 'Banni',
                              color: AppTheme.negative,
                            ),
                          ],
                          if (profile.pendingAvatarUrl != null &&
                              profile.pendingAvatarUrl!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.push(
                                AppRoutes.adminAvatarReview.replaceFirst(
                                  ':userId',
                                  profile.id,
                                ),
                              ),
                              child: const _Badge(
                                label: 'Photo',
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${profile.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profile.formattedBalance,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMe)
                  const SizedBox(width: 40)
                else
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'credit',
                        child: ListTile(
                          leading: Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.positive,
                          ),
                          title: Text('Créditer'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'debit',
                        child: ListTile(
                          leading: Icon(
                            Icons.remove_circle_outline,
                            color: AppTheme.negative,
                          ),
                          title: Text('Débiter'),
                        ),
                      ),
                      PopupMenuItem(
                        value: profile.isBanned ? 'unban' : 'ban',
                        child: ListTile(
                          leading: Icon(
                            profile.isBanned
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            color: profile.isBanned
                                ? AppTheme.positive
                                : AppTheme.warning,
                          ),
                          title: Text(
                            profile.isBanned ? 'Débannir' : 'Bannir',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset_password',
                        child: ListTile(
                          leading: Icon(
                            Icons.key_rounded,
                            color: AppTheme.info,
                          ),
                          title: Text('Réinitialiser le mot de passe'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_rounded,
                            color: AppTheme.negative,
                          ),
                          title: Text('Supprimer'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
