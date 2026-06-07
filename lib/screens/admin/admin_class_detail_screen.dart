import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/class_provider.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  const AdminClassDetailScreen({super.key, required this.classId, required this.className});

  final String classId;
  final String className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(classMembersProvider(classId));
    final withoutAsync = ref.watch(usersWithoutClassProvider);
    final state = ref.watch(classActionProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(className),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_rounded),
              tooltip: 'Ouvrir le chat de la classe',
              onPressed: () => context.push(AppRoutes.classChat(classId), extra: className as Object),
            ),
          ],
        ),
        body: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (members) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${members.length} membre${members.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.gold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    withoutAsync.when(
                      data: (available) => available.isEmpty
                          ? const SizedBox.shrink()
                          : TextButton.icon(
                              onPressed: () =>
                                  _showAddMemberDialog(context, ref, available),
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: const Text('Ajouter'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              'Aucun membre dans cette classe.',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                        itemBuilder: (context, i) => _MemberTile(
                          profile: members[i],
                          onRemove: () =>
                              _confirmRemove(context, ref, members[i]),
                        ),
                      ),
              ),
            ],
          ),
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
                leading: UserAvatar(username: p.username, avatarUrl: p.avatarUrl, radius: 20),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.profile, required this.onRemove});

  final Profile profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: UserAvatar(
        username: profile.username,
        avatarUrl: profile.avatarUrl,
        radius: 22,
      ),
      title: Text(
        profile.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('@${profile.username}'),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
        tooltip: 'Retirer de la classe',
        onPressed: onRemove,
      ),
    );
  }
}
