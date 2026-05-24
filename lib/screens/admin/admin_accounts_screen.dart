import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

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
          error: (error, _) => ErrorRetry(
            message: error.toString(),
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
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isMe = profile.id == currentId;

                return ListTile(
                  leading: UserAvatar(
                    username: profile.username,
                    avatarUrl: profile.avatarUrl,
                    radius: 20,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isBanned) ...[
                        const SizedBox(width: 6),
                        _Badge(
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
                  subtitle: Text('@${profile.username} · ${profile.formattedBalance}'),
                  trailing: isMe
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) => _handleAction(
                            ctx: context,
                            ref: ref,
                            action: value,
                            profile: profile,
                          ),
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
                  onTap: () => context.push('/user/${profile.username}'),
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
        } catch (error) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(error.toString())));
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
          ElevatedButton(
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '${isDebit ? '-' : '+'}${amount.toStringAsFixed(2)} SC appliqué',
            ),
            backgroundColor: isDebit ? AppTheme.negative : AppTheme.positive,
          ),
        );
      }
    } catch (error) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _ban(BuildContext ctx, WidgetRef ref, String userId) async {
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
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Compte banni')),
        );
      }
    } catch (error) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete(
    BuildContext ctx,
    WidgetRef ref,
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
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Compte supprimé')),
        );
      }
    } catch (error) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
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
