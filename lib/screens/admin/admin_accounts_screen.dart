import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';

class AdminAccountsScreen extends ConsumerWidget {
  const AdminAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final state = ref.watch(adminActionsProvider);
    final currentId = ref.watch(currentUserIdProvider) ?? '';

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tous les comptes')),
        body: profilesAsync.when(
          loading: () => const InlineLoader(),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(allProfilesProvider),
          ),
          data: (profiles) {
            if (profiles.isEmpty) {
              return const EmptyState(
                icon: Icons.people_rounded,
                title: 'Aucun compte',
              );
            }

            return ListView.separated(
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final p = profiles[i];
                final isMe = p.id == currentId;

                return ListTile(
                  leading: UserAvatar(
                    username: p.username,
                    avatarUrl: p.avatarUrl,
                    radius: 20,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.isBanned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.negative.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Banni',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.negative,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (p.pendingAvatarUrl != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _reviewAvatar(context, ref, p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Photo',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '@${p.username} · ${p.formattedBalance}',
                  ),
                  trailing: isMe
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) => _handleAction(
                              ctx: context,
                              ref: ref,
                              action: value,
                              profile: p),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'credit',
                              child: ListTile(
                                leading: Icon(Icons.add_circle_outline,
                                    color: AppTheme.positive),
                                title: Text('Créditer'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'debit',
                              child: ListTile(
                                leading: Icon(Icons.remove_circle_outline,
                                    color: AppTheme.negative),
                                title: Text('Débiter'),
                              ),
                            ),
                            PopupMenuItem(
                              value: p.isBanned ? 'unban' : 'ban',
                              child: ListTile(
                                leading: Icon(
                                  p.isBanned
                                      ? Icons.lock_open_rounded
                                      : Icons.block_rounded,
                                  color: p.isBanned
                                      ? AppTheme.positive
                                      : AppTheme.warning,
                                ),
                                title: Text(
                                  p.isBanned ? 'Débannir' : 'Bannir',
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_rounded,
                                    color: AppTheme.negative),
                                title: Text('Supprimer'),
                              ),
                            ),
                          ],
                        ),
                  onTap: () => context.push('/user/${p.username}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction({
    required BuildContext ctx,
    required WidgetRef ref,
    required String action,
    required dynamic profile,
  }) async {
    switch (action) {
      case 'credit':
      case 'debit':
        await _adjustBalance(ctx, ref, profile, action == 'debit');
      case 'ban':
        await _ban(ctx, ref, profile.id);
      case 'unban':
        try {
          await ref.read(adminActionsProvider.notifier).unbanUser(profile.id);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Compte débanni')),
            );
          }
        } catch (e) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      case 'delete':
        await _delete(ctx, ref, profile.id, profile.displayName);
    }
  }

  Future<void> _adjustBalance(
    BuildContext ctx,
    WidgetRef ref,
    dynamic profile,
    bool isDebit,
  ) async {
    final ctrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(isDebit ? 'Débiter le compte' : 'Créditer le compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
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
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final amount = double.tryParse(ctrl.text) ?? 0;
      if (amount <= 0) return;
      try {
        await ref.read(adminActionsProvider.notifier).adjustBalance(
              userId: profile.id,
              amount: isDebit ? -amount : amount,
              reason: reasonCtrl.text,
            );
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                '${isDebit ? '-' : '+'}${amount.toStringAsFixed(2)} SC appliqué',
              ),
              backgroundColor: isDebit ? AppTheme.negative : AppTheme.positive,
            ),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _reviewAvatar(
    BuildContext ctx,
    WidgetRef ref,
    dynamic profile,
  ) async {
    final result = await showDialog<String>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Photo en attente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Actuelle', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    UserAvatar(
                      username: profile.username,
                      avatarUrl: profile.avatarUrl,
                      radius: 32,
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Proposée', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    UserAvatar(
                      username: profile.username,
                      avatarUrl: profile.pendingAvatarUrl,
                      radius: 32,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, 'reject'),
            child: const Text('Refuser', style: TextStyle(color: AppTheme.negative)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, 'approve'),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      if (result == 'approve') {
        await ref
            .read(adminActionsProvider.notifier)
            .approveAvatarChange(profile.id);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Photo approuvée !'),
              backgroundColor: AppTheme.positive,
            ),
          );
        }
      } else {
        await ref
            .read(adminActionsProvider.notifier)
            .rejectAvatarChange(profile.id);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Photo refusée')),
          );
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _ban(BuildContext ctx, WidgetRef ref, String userId) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Bannir le compte'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Raison (optionnelle)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).banUser(
              userId,
              reason: ctrl.text.isEmpty ? null : ctrl.text,
            );
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Compte banni')),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _delete(
    BuildContext ctx,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
          'Supprimer définitivement le compte de $name ?\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).deleteUser(userId);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Compte supprimé')),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}
