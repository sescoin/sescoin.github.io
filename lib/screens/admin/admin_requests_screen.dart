import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/account_request.dart';
import '../../providers/admin_provider.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';

class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demandes de compte'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rafraîchir',
              onPressed: () => ref.invalidate(pendingRequestsProvider),
            ),
          ],
        ),
        body: requestsAsync.when(
          loading: () => const InlineLoader(),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(pendingRequestsProvider),
          ),
          data: (requests) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingRequestsProvider),
            child: requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(
                        height: 400,
                        child: EmptyState(
                          icon: Icons.inbox_rounded,
                          title: 'Aucune demande en attente',
                          subtitle: 'Tire vers le bas pour rafraîchir',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final req = requests[i];
                  final hasAvatar = req.avatarUrl != null && req.avatarUrl!.isNotEmpty;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                username: req.username,
                                avatarUrl: req.avatarUrl,
                                radius: 28,
                                onTap: hasAvatar
                                    ? () => _showAvatarPreview(context, req)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '@${req.username}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasAvatar) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _showAvatarPreview(context, req),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        req.avatarUrl!,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 72,
                                          height: 72,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.broken_image_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Photo de profil jointe\nAppuie pour agrandir',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.open_in_full_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _reject(context, ref, req.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.negative,
                                    side: const BorderSide(color: AppTheme.negative),
                                  ),
                                  child: const Text('Refuser'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _approve(context, ref, req.id),
                                  child: const Text('Approuver'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarPreview(
    BuildContext context,
    AccountRequest req,
  ) async {
    final avatarUrl = req.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${req.username}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 240,
                    alignment: Alignment.center,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_rounded, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext ctx,
    WidgetRef ref,
    String requestId,
  ) async {
    final balanceCtrl = TextEditingController(text: '100');
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Approuver le compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Solde initial à attribuer :'),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'SC'),
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
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final balance = double.tryParse(balanceCtrl.text) ?? 100;
      try {
        await ref.read(adminActionsProvider.notifier).approveRequest(
              requestId: requestId,
              initialBalance: balance,
            );
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Compte approuvé avec $balance SC !'),
              backgroundColor: AppTheme.positive,
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

  Future<void> _reject(
    BuildContext ctx,
    WidgetRef ref,
    String requestId,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Refuser la demande'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Raison (optionnelle)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).rejectRequest(
              requestId: requestId,
              reason: reasonCtrl.text.isEmpty ? null : reasonCtrl.text,
            );
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}
