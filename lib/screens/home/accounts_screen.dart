import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Annuaire des comptes, classés du plus riche au plus modeste.
///
/// Sert de porte d'entrée vers la fiche publique d'un compte, d'où partent
/// les actions (transfert, demande de prêt).
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Tri par solde décroissant, puis filtre de recherche. Le rang affiché
  /// reste celui du classement complet : filtrer ne renumérote pas.
  List<(int, Profile)> _ranked(List<Profile> profiles) {
    final sorted = [...profiles]
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final ranked = <(int, Profile)>[];
    for (var i = 0; i < sorted.length; i++) {
      ranked.add((i + 1, sorted[i]));
    }
    if (_query.isEmpty) return ranked;

    final q = _query.toLowerCase();
    return ranked
        .where((e) =>
            e.$2.username.toLowerCase().contains(q) ||
            e.$2.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final currentId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comptes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un compte',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: profilesAsync.when(
              loading: () => const InlineLoader(message: 'Chargement...'),
              error: (e, _) => ErrorRetry(
                message: 'Impossible de charger les comptes',
                onRetry: () => ref.invalidate(allProfilesProvider),
              ),
              data: (profiles) {
                final ranked = _ranked(profiles);
                if (ranked.isEmpty) {
                  return EmptyState(
                    icon: Icons.person_search_rounded,
                    title: _query.isEmpty
                        ? 'Aucun compte'
                        : 'Aucun résultat',
                    subtitle: _query.isEmpty
                        ? 'Les comptes apparaîtront ici'
                        : 'Aucun compte ne correspond à « $_query »',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: ranked.length,
                  itemBuilder: (context, i) {
                    final (rank, profile) = ranked[i];
                    return FadeSlideIn.staggered(
                      key: ValueKey(profile.id),
                      index: i,
                      child: _AccountCard(
                        rank: rank,
                        profile: profile,
                        isMe: profile.id == currentId,
                        onTap: () =>
                            context.push('/user/${profile.username}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.rank,
    required this.profile,
    required this.isMe,
    required this.onTap,
  });

  final int rank;
  final Profile profile;
  final bool isMe;
  final VoidCallback onTap;

  /// Les trois premiers rangs se démarquent, le reste reste neutre.
  Color? _podiumColor() => switch (rank) {
        1 => const Color(0xFFD4AF37),
        2 => const Color(0xFF9AA3B2),
        3 => const Color(0xFFB87333),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final podium = _podiumColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: podium != null ? 16 : 14,
                      fontWeight:
                          podium != null ? FontWeight.w900 : FontWeight.w700,
                      color: podium ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                UserAvatar(
                  username: profile.username,
                  avatarUrl: profile.avatarUrl,
                  radius: 20,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'moi',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${profile.balance.toStringAsFixed(2)} SC',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
