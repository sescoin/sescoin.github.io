import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/user_avatar.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_explorer_provider.dart';
import '../../transaction/global_transaction_tile.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    super.key,
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(username));

    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          message: 'Impossible de charger ce profil',
          onRetry: () => ref.invalidate(publicProfileProvider(username)),
        ),
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Profil introuvable',
              subtitle: 'Cet utilisateur n’existe pas ou n’est plus disponible',
            );
          }

          final transactionsAsync = ref.watch(globalTransactionsProvider);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      UserAvatar(
                        username: profile.username,
                        avatarUrl: profile.avatarUrl,
                        radius: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${profile.username}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Solde : ${profile.formattedBalance}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Transactions récentes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              transactionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorRetry(
                  message: 'Impossible de charger les transactions',
                  onRetry: () => ref.invalidate(globalTransactionsProvider),
                ),
                data: (transactions) {
                  final filtered = transactions
                      .where(
                        (tx) =>
                            tx.fromUserId == profile.id || tx.toUserId == profile.id,
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Aucune transaction visible',
                      subtitle: 'Les mouvements de ce profil apparaîtront ici',
                    );
                  }

                  return Column(
                    children: filtered
                        .map(
                          (transaction) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlobalTransactionTile(transaction: transaction),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
