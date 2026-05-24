import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
  final Profile profile;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.06)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? AppTheme.gold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
                fontSize: rank <= 3 ? 18 : 16,
              ),
            ),
          ),
          UserAvatar(
            username: profile.username,
            avatarUrl: profile.avatarUrl,
            radius: 22,
          ),
          const SizedBox(width: 14),
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
                    fontSize: 17,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              profile.formattedBalance,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
                fontSize: highlighted ? 16 : 15,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
