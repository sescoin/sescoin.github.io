import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/account_request.dart';
import '../../models/class_room.dart';
import '../../providers/admin_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/service_providers.dart';
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
                          subtitle: 'Tire vers le bas pour rafraîchir',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _RequestCard(
                      req: requests[i],
                      classes: classes,
                      onApprove: (balance, classId) =>
                          _approve(context, ref, requests[i], balance, classId),
                      onReject: () => _reject(context, ref, requests[i].id),
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Compte approuvé avec $balance SC !'),
            backgroundColor: AppTheme.positive,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
      builder: (d) => AlertDialog(
        title: const Text('Refuser la demande'),
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
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).rejectRequest(
              requestId: requestId,
              reason: reason.isEmpty ? null : reason,
            );
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx)
              .showSnackBar(SnackBar(content: Text(e.toString())));
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
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: const Text('Approuver le compte'),
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
    );

    final balance = double.tryParse(balanceCtrl.text) ?? 100;
    balanceCtrl.dispose();

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
                Column(
                  children: [
                    UserAvatar(
                      username: widget.req.username,
                      avatarUrl: widget.req.avatarUrl,
                      radius: 28,
                    ),
                    if (hasAvatar)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: () =>
                              _showAvatarPreview(context, widget.req),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            size: 16,
                            color: AppTheme.gold,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded,
                                size: 14, color: AppTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              _selectedClass?.name ?? 'Aucune classe',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.classes.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded,
                                  size: 12, color: AppTheme.gold),
                            ],
                          ],
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
      builder: (d) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req.displayName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text('@${req.username}',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 240,
                    alignment: Alignment.center,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_rounded, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppTheme.gold
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
