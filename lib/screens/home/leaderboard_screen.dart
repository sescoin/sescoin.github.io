import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/user_avatar.dart';
import '../../providers/profile_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classement')),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetry(
          message: 'Impossible de charger le classement',
          onRetry: () => ref.invalidate(leaderboardStreamProvider),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const EmptyState(
              icon: Icons.leaderboard_rounded,
              title: 'Aucun profil disponible',
              subtitle: 'Le classement apparaîtra ici',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      UserAvatar(
                        username: profile.username,
                        avatarUrl: profile.avatarUrl,
                        radius: 18,
                      ),
                    ],
                  ),
                  title: Text(
                    profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('@${profile.username}'),
                  trailing: Text(
                    profile.formattedBalance,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
