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

          final topThree = profiles.take(3).toList();
          final others = profiles.skip(3).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF161A31), Color(0xFF232A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Podium SES Coin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _PodiumCard(
                            rank: 2,
                            height: 132,
                            profile: topThree.length > 1 ? topThree[1] : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PodiumCard(
                            rank: 1,
                            height: 164,
                            profile: topThree.first,
                            highlighted: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PodiumCard(
                            rank: 3,
                            height: 118,
                            profile: topThree.length > 2 ? topThree[2] : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Suite du classement',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...others.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RankingTile(
                          rank: entry.key + 4,
                          profile: entry.value,
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.height,
    required this.profile,
    this.highlighted = false,
  });

  final int rank;
  final double height;
  final dynamic profile;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        highlighted ? AppTheme.gold : Colors.white.withValues(alpha: 0.08);
    final fgColor = highlighted ? Colors.black : Colors.white;

    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: profile == null
          ? Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: fgColor.withValues(alpha: highlighted ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: fgColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                UserAvatar(
                  username: profile.username,
                  avatarUrl: profile.avatarUrl,
                  radius: 22,
                ),
                const SizedBox(height: 10),
                Text(
                  profile.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.formattedBalance,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fgColor.withValues(alpha: highlighted ? 1 : 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.profile,
  });

  final int rank;
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$rank',
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
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
