import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/class_provider.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  const AdminClassDetailScreen(
      {super.key, required this.classId, required this.className});

  final String classId;
  final String className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(classMembersProvider(classId));
    final withoutAsync = ref.watch(usersWithoutClassProvider);
    final state = ref.watch(classActionProvider);
    final accent = context.accent;

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: Text(className)),
        body: membersAsync.when(
          loading: () => const InlineLoader(message: 'Chargement...'),
          error: (e, _) => ErrorRetry(
            message: 'Impossible de charger les membres',
            onRetry: () => ref.invalidate(classMembersProvider(classId)),
          ),
          data: (members) {
            final available = withoutAsync.valueOrNull ?? const <Profile>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── En-tête de la classe ──────────────────────────────────
                FadeSlideIn.staggered(
                  index: 0,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A1A2E),
                          Color.lerp(const Color(0xFF16213E), accent, 0.22)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                className,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                members.length == 1
                                    ? 'un membre'
                                    : '${members.length} membres',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Ouvrir le chat de la classe',
                          onPressed: () => context.push(
                            AppRoutes.classChat(classId),
                            extra: className as Object,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Barre d'actions ───────────────────────────────────────
                FadeSlideIn.staggered(
                  index: 1,
                  child: Row(
                    children: [
                      Text(
                        'Membres',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      if (available.isNotEmpty)
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _showAddMemberDialog(context, ref, available),
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Ajouter'),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent.withValues(alpha: 0.14),
                            foregroundColor: accent,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ── Membres ───────────────────────────────────────────────
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.group_rounded,
                      title: 'Aucun membre',
                      subtitle: 'Les membres ajoutés apparaîtront ici',
                    ),
                  )
                else
                  for (var i = 0; i < members.length; i++)
                    FadeSlideIn.staggered(
                      key: ValueKey(members[i].id),
                      index: 2 + i,
                      child: _MemberTile(
                        profile: members[i],
                        onRemove: () => _confirmRemove(context, ref, members[i]),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddMemberDialog(
    BuildContext context,
    WidgetRef ref,
    List<Profile> available,
  ) async {
    final selected = await showDialog<Profile>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un membre'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (context, i) {
              final p = available[i];
              return ListTile(
                leading: UserAvatar(
                    username: p.username, avatarUrl: p.avatarUrl, radius: 20),
                title: Text(p.displayName),
                subtitle: Text('@${p.username}'),
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await ref
        .read(classActionProvider.notifier)
        .setUserClass(selected.id, classId);
    ref.invalidate(classMembersProvider(classId));
    ref.invalidate(usersWithoutClassProvider);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${profile.displayName} ?'),
        content: const Text('Ce membre sera retiré de la classe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(classActionProvider.notifier)
        .setUserClass(profile.id, null);
    ref.invalidate(classMembersProvider(classId));
    ref.invalidate(usersWithoutClassProvider);
  }
}

// ── Tuile de membre ────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.profile, required this.onRemove});

  final Profile profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              UserAvatar(
                username: profile.username,
                avatarUrl: profile.avatarUrl,
                radius: 21,
              ),
              const SizedBox(width: 12),
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              IconButton(
                icon: const Icon(
                  Icons.person_remove_rounded,
                  color: AppTheme.negative,
                  size: 20,
                ),
                tooltip: 'Retirer de la classe',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
