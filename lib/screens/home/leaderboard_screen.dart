import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
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

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _RankingTile(
                rank: index + 1,
                profile: profile,
                highlighted: index == 0,
              );
            },
          );
        },
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.profile,
    required this.highlighted,
  });

  final int rank;
  final dynamic profile;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: highlighted
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          UserAvatar(
            username: profile.username,
            avatarUrl: profile.avatarUrl,
            radius: 28,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              profile.formattedBalance,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
                fontSize: highlighted ? 18 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
