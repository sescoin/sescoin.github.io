import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              onPressed: () => ref.invalidate(classListProvider),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nouvelle classe'),
          backgroundColor: AppTheme.gold,
          foregroundColor: Colors.black87,
        ),
        body: classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur : $e'),
                TextButton(
                  onPressed: () => ref.invalidate(classListProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
          data: (classes) => classes.isEmpty
              ? _EmptyClasses(
                  onCreateTap: () => _showCreateDialog(context, ref),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: classes.length,
                  itemBuilder: (context, i) => _ClassCard(
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
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle classe'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom de la classe'),
          textCapitalization: TextCapitalization.words,
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
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true) return;
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
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la classe'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nouveau nom'),
          textCapitalization: TextCapitalization.words,
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
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true) return;
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
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${classRoom.name}" ?'),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: AppTheme.gold, size: 22),
        ),
        title: Text(
          classRoom.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${classRoom.memberCount} membre${classRoom.memberCount > 1 ? 's' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') onRename();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'rename', child: Text('Renommer')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Aucune classe créée',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Crée une classe pour organiser tes membres.',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer une classe'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: Colors.black87),
          ),
        ],
      ),
    );
  }
}
