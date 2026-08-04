import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
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

          final podium = profiles.take(3).toList();
          final rest = profiles.skip(3).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (podium.isNotEmpty)
                FadeSlideIn(child: _Podium(profiles: podium)),
              const SizedBox(height: 18),
              ...rest.indexed.map((entry) {
                final (index, profile) = entry;
                return FadeSlideIn.staggered(
                  key: ValueKey(profile.username),
                  index: index + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RankingTile(
                      rank: index + 4,
                      profile: profile,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ── Podium top 3 ───────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context) {
    final first = profiles.isNotEmpty ? profiles[0] : null;
    final second = profiles.length > 1 ? profiles[1] : null;
    final third = profiles.length > 2 ? profiles[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: second != null
              ? _PodiumSpot(
                  profile: second,
                  rank: 2,
                  color: const Color(0xFFC9D1D9),
                  height: 88,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: first != null
              ? _PodiumSpot(
                  profile: first,
                  rank: 1,
                  color: AppTheme.gold,
                  height: 112,
                  crowned: true,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: third != null
              ? _PodiumSpot(
                  profile: third,
                  rank: 3,
                  color: const Color(0xFFCD7F32),
                  height: 72,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    required this.profile,
    required this.rank,
    required this.color,
    required this.height,
    this.crowned = false,
  });

  final Profile profile;
  final int rank;
  final Color color;
  final double height;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crowned) ...[
          const Text('👑', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
        ],
        // Citation au-dessus de la photo, réservée au podium.
        if ((profile.quote ?? '').isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              profile.quote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.3,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: UserAvatar(
            username: profile.username,
            avatarUrl: profile.avatarUrl,
            radius: crowned ? 30 : 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          profile.formattedBalance,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.55),
                color.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: crowned ? 34 : 26,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tuile de classement (rangs 4+) ─────────────────────────────────────────────

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.profile,
  });

  final int rank;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Color(0xFF8E9AB3),
                fontWeight: FontWeight.w800,
                fontSize: 16,
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
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13.5,
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
                color: context.accent,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
