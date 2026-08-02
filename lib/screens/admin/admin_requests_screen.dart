import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/account_request.dart';
import '../../models/class_room.dart';
import '../../providers/admin_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/service_providers.dart';
import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/dispose_scope.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';

class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final state = ref.watch(adminActionsProvider);
    final classesAsync = ref.watch(classListProvider);
    final classes = classesAsync.valueOrNull ?? [];

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demandes de compte'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rafraîchir',
              onPressed: () => ref.invalidate(pendingRequestsProvider),
            ),
          ],
        ),
        body: requestsAsync.when(
          loading: () => const InlineLoader(),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(pendingRequestsProvider),
          ),
          data: (requests) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingRequestsProvider),
            child: requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(
                        height: 400,
                        child: EmptyState(
                          icon: Icons.inbox_rounded,
                          title: 'Aucune demande en attente',
                          subtitle: 'Glisser vers le bas pour actualiser',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => FadeSlideIn.staggered(
                      key: ValueKey(requests[i].id),
                      index: i,
                      child: _RequestCard(
                        req: requests[i],
                        classes: classes,
                        onApprove: (balance, classId) => _approve(
                            context, ref, requests[i], balance, classId),
                        onReject: () => _reject(context, ref, requests[i].id),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext ctx,
    WidgetRef ref,
    AccountRequest req,
    double balance,
    String? classId,
  ) async {
    try {
      // Mettre à jour la classe si nécessaire
      if (classId != req.classId) {
        await ref
            .read(profileServiceProvider)
            .setAccountRequestClass(req.id, classId);
      }
      await ref.read(adminActionsProvider.notifier).approveRequest(
            requestId: req.id,
            initialBalance: balance,
          );
      if (ctx.mounted) {
        AppFeedback.success(ctx, 'Compte approuvé avec $balance SC !');
      }
    } catch (e) {
      if (ctx.mounted) {
        AppFeedback.error(ctx, e);
      }
    }
  }

  Future<void> _reject(
    BuildContext ctx,
    WidgetRef ref,
    String requestId,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => DisposeScope(
        disposables: [reasonCtrl],
        child: AppDialog(
          icon: Icons.person_off_rounded,
          tone: AppDialogTone.danger,
          title: 'Refuser la demande',
          subtitle: 'L\'élève sera informé du refus',
          content: TextField(
            controller: reasonCtrl,
            decoration:
                const InputDecoration(labelText: 'Raison (optionnelle)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
              child: const Text('Refuser'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonCtrl.text;
    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).rejectRequest(
              requestId: requestId,
              reason: reason.isEmpty ? null : reason,
            );
      } catch (e) {
        if (ctx.mounted) {
          AppFeedback.error(ctx, e);
        }
      }
    }
  }
}

// ── Carte de demande ──────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.req,
    required this.classes,
    required this.onApprove,
    required this.onReject,
  });

  final AccountRequest req;
  final List<ClassRoom> classes;
  final Future<void> Function(double balance, String? classId) onApprove;
  final VoidCallback onReject;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.req.classId;
  }

  ClassRoom? get _selectedClass =>
      widget.classes.where((c) => c.id == _selectedClassId).firstOrNull;

  Future<void> _showApproveDialog() async {
    final balanceCtrl = TextEditingController(text: '100');
    String? dialogClassId = _selectedClassId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => DisposeScope(
        disposables: [balanceCtrl],
        child: StatefulBuilder(
          builder: (d, setS) => AppDialog(
            icon: Icons.how_to_reg_rounded,
            title: 'Approuver le compte',
            subtitle: '@${widget.req.username}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solde initial à attribuer :'),
                const SizedBox(height: 8),
                TextField(
                  controller: balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: 'SC'),
                ),
                if (widget.classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Classe :',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ClassChip(
                        label: 'Aucune',
                        selected: dialogClassId == null,
                        onTap: () => setS(() => dialogClassId = null),
                      ),
                      ...widget.classes.map(
                        (c) => _ClassChip(
                          label: c.name,
                          selected: dialogClassId == c.id,
                          onTap: () => setS(() => dialogClassId = c.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Approuver'),
              ),
            ],
          ),
        ),
      ),
    );

    final balance = double.tryParse(balanceCtrl.text) ?? 100;

    if (confirmed == true) {
      setState(() => _selectedClassId = dialogClassId);
      await widget.onApprove(balance, dialogClassId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.req.avatarUrl != null &&
        widget.req.avatarUrl!.isNotEmpty &&
        widget.req.avatarUrl!.startsWith('http');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : avatar + nom + classe ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // La pastille d'agrandissement chevauche le bord de la photo
                // plutôt que d'occuper une ligne sous elle.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      username: widget.req.username,
                      avatarUrl: widget.req.avatarUrl,
                      radius: 28,
                    ),
                    if (hasAvatar)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: () => _showAvatarPreview(context, widget.req),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: context.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.open_in_full_rounded,
                              size: 12,
                              color: context.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.req.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '@${widget.req.username}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Classe choisie + possibilité de changer
                      GestureDetector(
                        onTap: widget.classes.isEmpty
                            ? null
                            : () => _showClassPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_rounded,
                                  size: 14, color: context.accent),
                              const SizedBox(width: 4),
                              Text(
                                _selectedClass?.name ?? 'Aucune classe',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.classes.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.edit_rounded,
                                    size: 12, color: context.accent),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Actions ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.negative,
                      side: const BorderSide(color: AppTheme.negative),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showApproveDialog,
                    child: const Text('Approuver'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClassPicker(BuildContext context) async {
    String? picked = _selectedClassId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: const Text('Changer la classe'),
          content: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ClassChip(
                label: 'Aucune',
                selected: picked == null,
                onTap: () => setS(() => picked = null),
              ),
              ...widget.classes.map(
                (c) => _ClassChip(
                  label: c.name,
                  selected: picked == c.id,
                  onTap: () => setS(() => picked = c.id),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _selectedClassId = picked);
    }
  }

  Future<void> _showAvatarPreview(
    BuildContext context,
    AccountRequest req,
  ) async {
    final avatarUrl = req.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (d) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            // La photo occupe tout le cadre, en carré.
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        alignment: Alignment.center,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_rounded, size: 44),
                ),
              ),
            ),
            // Dégradé sombre pour rendre le nom lisible sur n'importe quelle
            // photo.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      req.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${req.username}',
                      style: TextStyle(
                        color: context.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fermeture en pastille flottante.
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(d),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? accent
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
