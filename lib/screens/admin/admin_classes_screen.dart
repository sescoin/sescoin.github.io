import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/dispose_scope.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/class_room.dart';
import '../../providers/class_provider.dart';

class AdminClassesScreen extends ConsumerWidget {
  const AdminClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);
    final state = ref.watch(classActionProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des classes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualiser',
              onPressed: () => ref.invalidate(classListProvider),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nouvelle classe'),
          backgroundColor: context.accent,
          foregroundColor: context.onAccent,
        ),
        body: classesAsync.when(
          loading: () => const InlineLoader(message: 'Chargement...'),
          error: (e, _) => ErrorRetry(
            message: 'Impossible de charger les classes',
            onRetry: () => ref.invalidate(classListProvider),
          ),
          data: (classes) => classes.isEmpty
              ? const EmptyState(
                  icon: Icons.school_rounded,
                  title: 'Aucune classe',
                  subtitle: 'Les classes créées apparaîtront ici',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: classes.length,
                  itemBuilder: (context, i) => FadeSlideIn.staggered(
                    key: ValueKey(classes[i].id),
                    index: i,
                    child: _ClassCard(
                      classRoom: classes[i],
                      onTap: () => context.push(
                        AppRoutes.adminClassDetail(classes[i].id),
                        extra: {'name': classes[i].name},
                      ),
                      onRename: () =>
                          _showRenameDialog(context, ref, classes[i]),
                      onDelete: () =>
                          _showDeleteDialog(context, ref, classes[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [ctrl],
        child: AppDialog(
          icon: Icons.add_rounded,
          title: 'Nouvelle classe',
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom de la classe'),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    final name = ctrl.text.trim();
    if (confirmed != true || name.isEmpty) return;
    await ref.read(classActionProvider.notifier).createClass(name);
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    ClassRoom classRoom,
  ) async {
    final ctrl = TextEditingController(text: classRoom.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [ctrl],
        child: AppDialog(
          icon: Icons.drive_file_rename_outline_rounded,
          title: 'Renommer la classe',
          subtitle: classRoom.name,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nouveau nom'),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Renommer'),
            ),
          ],
        ),
      ),
    );
    final name = ctrl.text.trim();
    if (confirmed != true || name.isEmpty) return;
    await ref
        .read(classActionProvider.notifier)
        .renameClass(classRoom.id, name);
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ClassRoom classRoom,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        tone: AppDialogTone.danger,
        title: 'Supprimer « ${classRoom.name} » ?',
        subtitle: 'Cette action est définitive',
        content: Text(
          'Les ${classRoom.memberCount} membre(s) seront retirés de cette classe. '
          'Les messages du chat de cette classe seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(classActionProvider.notifier)
        .deleteClass(classRoom.id);
  }
}

// ── Carte de classe ────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classRoom,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ClassRoom classRoom;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(Icons.school_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classRoom.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            classRoom.memberCount == 1
                                ? 'un membre'
                                : '${classRoom.memberCount} membres',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (v) {
                    if (v == 'rename') onRename();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded, size: 20),
                        title: Text('Renommer'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_rounded,
                          size: 20,
                          color: AppTheme.negative,
                        ),
                        title: Text(
                          'Supprimer',
                          style: TextStyle(color: AppTheme.negative),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
