import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/chat_read.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

// ── Écran principal ────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.classId, this.className});

  /// null = chat global (onglets), non-null = chat de classe direct
  final String? classId;
  final String? className;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  bool get _isClassMode => widget.classId != null;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabs(bool hasClass) {
    if (_tabController != null) return;
    if (!_isClassMode && hasClass) {
      _tabController = TabController(length: 2, vsync: this);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.role == 'admin';
    final userClassId = profile?.classId;
    final hasClass = userClassId != null;

    if (!_isClassMode && hasClass) {
      _initTabs(hasClass);
    }

    // ── Mode classe direct (depuis admin panel) ──────────────────────────────
    if (_isClassMode) {
      return _ClassChatScaffold(
        classId: widget.classId!,
        className: widget.className ?? 'Classe',
        isAdmin: isAdmin,
      );
    }

    // ── Mode onglets Global + Ma Classe ──────────────────────────────────────
    if (hasClass && _tabController != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'Annonces', icon: Icon(Icons.campaign_rounded, size: 18)),
              Tab(text: 'Ma Classe', icon: const Icon(Icons.school_rounded, size: 18)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _GlobalChatBody(isAdmin: isAdmin),
            _ClassChatBody(
              classId: userClassId,
              isAdmin: isAdmin,
            ),
          ],
        ),
      );
    }

    // ── Mode global seul (pas de classe) ────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showGlobalChatInfo(context),
          ),
        ],
      ),
      body: _GlobalChatBody(isAdmin: isAdmin),
    );
  }

  void _showGlobalChatInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chat global'),
        content: const Text(
          'Seul l\'administrateur peut envoyer des messages ici.\n\n'
          'Tu peux envoyer une demande de prêt visible par tous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

// ── Scaffold classe (mode direct depuis admin) ─────────────────────────────────

class _ClassChatScaffold extends StatelessWidget {
  const _ClassChatScaffold({
    required this.classId,
    required this.className,
    required this.isAdmin,
  });

  final String classId;
  final String className;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(className)),
      body: _ClassChatBody(classId: classId, isAdmin: isAdmin),
    );
  }
}

// ── Corps du chat global ───────────────────────────────────────────────────────

class _GlobalChatBody extends ConsumerStatefulWidget {
  const _GlobalChatBody({required this.isAdmin});

  final bool isAdmin;

  @override
  ConsumerState<_GlobalChatBody> createState() => _GlobalChatBodyState();
}

class _GlobalChatBodyState extends ConsumerState<_GlobalChatBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollFab = false;
  bool _isNearBottom = true;
  final Set<String> _locallyDeletedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final dist =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final nearBottom = dist <= 68;
    final should = dist > 120;
    if (should != _showScrollFab || nearBottom != _isNearBottom) {
      setState(() {
        _showScrollFab = should;
        _isNearBottom = nearBottom;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendAdminMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(chatActionProvider.notifier).sendGlobalMessage(text);
  }

  Future<void> _adminDeleteMessage(ChatMessage msg) async {
    setState(() => _locallyDeletedIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).adminDeleteMessage(msg.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _deleteOwnLoanRequest(ChatMessage msg) async {
    setState(() => _locallyDeletedIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).deleteMessage(msg.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _showLoanRequestDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demande de prêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant souhaité (SC)',
                prefixIcon: Icon(Icons.monetization_on_outlined),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Motif (optionnel)',
                prefixIcon: Icon(Icons.notes_rounded),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
    amountCtrl.dispose();
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();

    if (confirmed != true || amount == null || amount <= 0) return;

    final result = await ref
        .read(chatActionProvider.notifier)
        .sendLoanRequestChat(amount, note: note.isEmpty ? null : note);

    if (mounted && result == null) {
      _showSnackBar('Erreur lors de l\'envoi.', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(globalMessagesProvider);
    final chatState = ref.watch(chatActionProvider);
    final currentUserId =
        ref.watch(currentUserIdProvider) ?? '';

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erreur : $e')),
                data: (messages) {
                  final visible = messages
                      .where((m) =>
                          !m.isDeleted &&
                          !_locallyDeletedIds.contains(m.id))
                      .toList();

                  if (visible.isEmpty) {
                    return const _EmptyChat(
                      message: 'Aucune annonce pour l\'instant.',
                    );
                  }

                  // Auto-scroll si en bas
                  if (_isNearBottom) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );
                  }

                  final items = <_ChatItem>[];
                  for (int i = 0; i < visible.length; i++) {
                    final msg = visible[i];
                    final prev = i > 0 ? visible[i - 1] : null;
                    if (prev == null ||
                        msg.createdAt
                                .difference(prev.createdAt)
                                .inMinutes >=
                            15) {
                      items.add(_ChatItem.divider(msg.createdAt));
                    }
                    final showHeader =
                        prev == null || prev.userId != msg.userId;
                    items.add(_ChatItem.message(msg, showHeader: showHeader));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item.isDivider) {
                        return _TimeDivider(time: item.dividerTime!);
                      }
                      final msg = item.message!;
                      final isOwn = msg.userId == currentUserId;
                      final canDelete = widget.isAdmin ||
                          (isOwn && msg.isLoanRequest);

                      if (msg.isLoanRequest) {
                        return _LoanRequestBubble(
                          message: msg,
                          isOwn: isOwn,
                          showHeader: item.showHeader,
                          onDelete: canDelete
                              ? () => widget.isAdmin
                                  ? _adminDeleteMessage(msg)
                                  : _deleteOwnLoanRequest(msg)
                              : null,
                          onTapUsername: () =>
                              context.push('/user/${msg.username}'),
                        );
                      }

                      return _MessageBubble(
                        message: msg,
                        isOwn: isOwn,
                        showHeader: item.showHeader,
                        readers: const [],
                        onTapUsername: () =>
                            context.push('/user/${msg.username}'),
                        onLongPress: widget.isAdmin
                            ? () => _adminDeleteMessage(msg)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.isAdmin)
              _InputBar(
                controller: _controller,
                chatState: chatState,
                onSend: _sendAdminMessage,
                hintText: 'Écrire une annonce…',
              )
            else
              _LoanRequestBar(onTap: _showLoanRequestDialog),
          ],
        ),
        if (_showScrollFab)
          Positioned(
            bottom: 72,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black87,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    );
  }
}

// ── Corps du chat de classe ────────────────────────────────────────────────────

class _ClassChatBody extends ConsumerStatefulWidget {
  const _ClassChatBody({required this.classId, required this.isAdmin});

  final String classId;
  final bool isAdmin;

  @override
  ConsumerState<_ClassChatBody> createState() => _ClassChatBodyState();
}

class _ClassChatBodyState extends ConsumerState<_ClassChatBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _muteTimer;
  bool _showScrollFab = false;
  bool _isNearBottom = true;
  final Set<String> _locallyDeletedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _muteTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final dist =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final nearBottom = dist <= 68;
    final should = dist > 120;
    if (should != _showScrollFab || nearBottom != _isNearBottom) {
      setState(() {
        _showScrollFab = should;
        _isNearBottom = nearBottom;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatActionProvider.notifier).clearMuteIfExpired();
    if (ref.read(chatActionProvider).isMuted) return;

    _controller.clear();
    final result = await ref
        .read(chatActionProvider.notifier)
        .sendClassMessage(widget.classId, text);

    if (!mounted || result == null) return;
    if (result.warning) {
      final remaining = 3 - result.warningCount;
      if (result.muted) {
        _showSnackBar(
          '🔇 Vous avez été muet 10 minutes pour comportement inapproprié.',
          Colors.red,
        );
        _startMuteTimer();
      } else {
        _showSnackBar(
          '⚠️ Avertissement ${result.warningCount}/3 — message censuré.'
          '${remaining > 0 ? ' Encore $remaining avant d\'être muet.' : ''}',
          Colors.orange,
        );
      }
    }
  }

  void _startMuteTimer() {
    _muteTimer?.cancel();
    _muteTimer = Timer(const Duration(minutes: 10), () {
      if (mounted) ref.read(chatActionProvider.notifier).clearMuteIfExpired();
    });
  }

  Future<void> _editMessage(ChatMessage message) async {
    final ctrl = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => _ChatDialog(
        icon: Icons.edit_rounded,
        title: 'Modifier le message',
        accentColor: AppTheme.gold,
        content: TextField(
          controller: ctrl,
          maxLength: 500,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Ton message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (!mounted) return;
    if (newContent == null ||
        newContent.isEmpty ||
        newContent == message.content) {
      return;
    }

    try {
      final result = await ref
          .read(chatActionProvider.notifier)
          .editClassMessage(message.id, newContent);
      if (!mounted || result == null) return;
      if (result.muted) {
        _showSnackBar(
          '🔇 Vous avez été muet 10 minutes pour comportement inapproprié.',
          Colors.red,
        );
      } else if (result.warning) {
        final remaining = 3 - result.warningCount;
        _showSnackBar(
          '⚠️ Avertissement ${result.warningCount}/3 — message censuré.'
          '${remaining > 0 ? ' Encore $remaining avant d\'être muet.' : ''}',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ChatDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Supprimer le message ?',
        accentColor: Colors.red,
        content: Text(
          'Cette action est définitive.',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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

    setState(() => _locallyDeletedIds.add(message.id));
    try {
      if (widget.isAdmin) {
        await ref.read(chatActionProvider.notifier).adminDeleteMessage(message.id);
      } else {
        await ref.read(chatActionProvider.notifier).deleteMessage(message.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(message.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  void _showMessageActions(BuildContext context, ChatMessage message, bool isOwn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171929) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  'Options du message',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (isOwn)
                  _ChatActionTile(
                    icon: Icons.edit_rounded,
                    label: 'Modifier',
                    onTap: () {
                      Navigator.pop(context);
                      _editMessage(message);
                    },
                  ),
                if (isOwn) const SizedBox(height: 8),
                _ChatActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(classMessagesProvider(widget.classId));
    final chatState = ref.watch(chatActionProvider);
    final readsMap = ref.watch(chatReadsMapProvider);
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (messages) {
                  final visible = messages
                      .where((m) =>
                          !m.isDeleted &&
                          !_locallyDeletedIds.contains(m.id))
                      .toList();

                  if (visible.isEmpty) {
                    return const _EmptyChat(
                      message: 'Aucun message dans cette classe.',
                    );
                  }

                  if (_isNearBottom) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );
                  }

                  final items = <_ChatItem>[];
                  for (int i = 0; i < visible.length; i++) {
                    final msg = visible[i];
                    final prev = i > 0 ? visible[i - 1] : null;
                    if (prev == null ||
                        msg.createdAt
                                .difference(prev.createdAt)
                                .inMinutes >=
                            15) {
                      items.add(_ChatItem.divider(msg.createdAt));
                    }
                    final showHeader =
                        prev == null || prev.userId != msg.userId;
                    final readers = (readsMap[msg.id] ?? [])
                        .where((r) => r.userId != currentUserId)
                        .toList();
                    items.add(_ChatItem.message(
                      msg,
                      showHeader: showHeader,
                      readers: readers,
                    ));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item.isDivider) {
                        return _TimeDivider(time: item.dividerTime!);
                      }
                      final msg = item.message!;
                      final isOwn = msg.userId == currentUserId;
                      final canInteract =
                          (isOwn || widget.isAdmin) && !msg.isDeleted;
                      return _MessageBubble(
                        message: msg,
                        isOwn: isOwn,
                        showHeader: item.showHeader,
                        readers: item.readers,
                        onTapUsername: () =>
                            context.push('/user/${msg.username}'),
                        onLongPress: canInteract
                            ? () =>
                                _showMessageActions(context, msg, isOwn)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(
              controller: _controller,
              chatState: chatState,
              onSend: _send,
              hintText: 'Écrire un message…',
            ),
          ],
        ),
        if (_showScrollFab)
          Positioned(
            bottom: 72,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black87,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    );
  }
}

// ── Barre demande de prêt (utilisateurs dans le chat global) ──────────────────

class _LoanRequestBar extends StatelessWidget {
  const _LoanRequestBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161827) : theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.request_page_rounded),
              label: const Text('Envoyer une demande de prêt'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bulle demande de prêt ─────────────────────────────────────────────────────

class _LoanRequestBubble extends StatelessWidget {
  const _LoanRequestBubble({
    required this.message,
    required this.isOwn,
    required this.showHeader,
    required this.onTapUsername,
    this.onDelete,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showHeader;
  final VoidCallback onTapUsername;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 10 : 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: GestureDetector(
                onTap: onTapUsername,
                child: Row(
                  children: [
                    UserAvatar(
                      username: message.username,
                      avatarUrl: message.avatarUrl,
                      radius: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(left: 4, right: 40),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.gold.withValues(alpha: 0.12)
                  : AppTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.request_page_rounded,
                        color: AppTheme.gold, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Demande de prêt',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.red),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${message.loanAmount?.toStringAsFixed(0)} SC',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gold,
                  ),
                ),
                if (message.loanNote != null &&
                    message.loanNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.loanNote!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogue réutilisable ──────────────────────────────────────────────────────

class _ChatDialog extends StatelessWidget {
  const _ChatDialog({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1A1B2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action tile (bottom sheet) ────────────────────────────────────────────────

class _ChatActionTile extends StatelessWidget {
  const _ChatActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.onSurface;
    return Material(
      color: actionColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: actionColor, size: 21),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: actionColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: actionColor.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modèle interne ─────────────────────────────────────────────────────────────

class _ChatItem {
  _ChatItem._({
    this.message,
    this.dividerTime,
    this.showHeader = false,
    this.readers = const [],
  });

  factory _ChatItem.divider(DateTime time) => _ChatItem._(dividerTime: time);

  factory _ChatItem.message(
    ChatMessage msg, {
    required bool showHeader,
    List<ChatRead> readers = const [],
  }) =>
      _ChatItem._(message: msg, showHeader: showHeader, readers: readers);

  final ChatMessage? message;
  final DateTime? dividerTime;
  final bool showHeader;
  final List<ChatRead> readers;

  bool get isDivider => dividerTime != null;
}

// ── Séparateur temporel ───────────────────────────────────────────────────────

class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.time});

  final DateTime time;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(time.year, time.month, time.day);
    final hm = DateFormat('HH:mm').format(time);
    if (day == today) return hm;
    if (day == yesterday) return 'Hier $hm';
    return DateFormat('d MMM, HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 52, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showHeader,
    required this.readers,
    required this.onTapUsername,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showHeader;
  final List<ChatRead> readers;
  final VoidCallback onTapUsername;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return const SizedBox.shrink();

    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCensored = message.isCensored;

    final bubbleColor = isCensored
        ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
        : isOwn
            ? AppTheme.gold
            : (isDark ? const Color(0xFF2A2A3E) : Colors.white);

    final textColor = isCensored
        ? Colors.grey
        : isOwn
            ? Colors.black87
            : theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 10 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            GestureDetector(
              onTap: onTapUsername,
              child: UserAvatar(
                username: message.username,
                avatarUrl: message.avatarUrl,
                radius: 16,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showHeader && !isOwn)
                  GestureDetector(
                    onTap: onTapUsername,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        message.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isOwn ? 20 : 6),
                        bottomRight: Radius.circular(isOwn ? 6 : 20),
                      ),
                      border: isCensored
                          ? Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                              width: 1.1)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.6,
                        height: 1.38,
                        fontStyle: isCensored
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                      if (message.editedAt != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(modifié)',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                if (readers.isNotEmpty) _ReadReceiptRow(readers: readers),
              ],
            ),
          ),
          if (isOwn) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ── Accusés de lecture ────────────────────────────────────────────────────────

class _ReadReceiptRow extends StatefulWidget {
  const _ReadReceiptRow({required this.readers});

  final List<ChatRead> readers;

  @override
  State<_ReadReceiptRow> createState() => _ReadReceiptRowState();
}

class _ReadReceiptRowState extends State<_ReadReceiptRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 2),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _expanded
              ? _ExpandedReaders(
                  key: const ValueKey('exp'),
                  readers: widget.readers.take(4).toList(),
                  controller: _ctrl,
                )
              : _CompactReaders(
                  key: const ValueKey('cpt'),
                  readers: widget.readers,
                ),
        ),
      ),
    );
  }
}

class _CompactReaders extends StatelessWidget {
  const _CompactReaders({super.key, required this.readers});

  final List<ChatRead> readers;

  @override
  Widget build(BuildContext context) {
    final visible = readers.take(4).toList();
    final extra = readers.length - visible.length;
    const r = 7.0;
    const step = 11.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: r * 2,
          width: visible.length * step + r * 2 - step + 2,
          child: Stack(
            children: [
              for (int i = 0; i < visible.length; i++)
                Positioned(
                  left: i * step,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1,
                      ),
                    ),
                    child: UserAvatar(
                      username: visible[i].username,
                      avatarUrl: visible[i].avatarUrl,
                      radius: r,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 3),
          Text('+$extra',
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ],
    );
  }
}

class _ExpandedReaders extends StatelessWidget {
  const _ExpandedReaders({
    super.key,
    required this.readers,
    required this.controller,
  });

  final List<ChatRead> readers;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < readers.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _AnimatedReaderChip(
            reader: readers[i],
            controller: controller,
            index: i,
            total: readers.length,
          ),
        ],
      ],
    );
  }
}

class _AnimatedReaderChip extends StatelessWidget {
  const _AnimatedReaderChip({
    required this.reader,
    required this.controller,
    required this.index,
    required this.total,
  });

  final ChatRead reader;
  final AnimationController controller;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final start = (index / total * 0.5).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    final scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.elasticOut)),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.easeIn)),
    );
    return ScaleTransition(
      scale: scale,
      child: FadeTransition(
        opacity: fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              username: reader.username,
              avatarUrl: reader.avatarUrl,
              radius: 8,
            ),
            const SizedBox(height: 2),
            Text(
              reader.displayName,
              style: TextStyle(fontSize: 8, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.chatState,
    required this.onSend,
    required this.hintText,
  });

  final TextEditingController controller;
  final ChatState chatState;
  final VoidCallback onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final isMuted = chatState.isMuted;
    final errorMsg = chatState.error;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorMsg != null)
          Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(errorMsg,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        if (isMuted)
          Container(
            width: double.infinity,
            color: Colors.orange.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.volume_off_rounded, color: Colors.orange, size: 15),
                SizedBox(width: 8),
                Text(
                  'Vous êtes muet — comportement inapproprié détecté.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color:
                isDark ? const Color(0xFF161827) : theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF23273F)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            onSend();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: controller,
                          enabled: !isMuted && !chatState.isSending,
                          maxLength: 500,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText:
                                isMuted ? 'Vous êtes muet…' : hintText,
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(
                    isSending: chatState.isSending,
                    isMuted: isMuted,
                    onPressed: onSend,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bouton d'envoi ────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isSending,
    required this.isMuted,
    required this.onPressed,
  });

  final bool isSending;
  final bool isMuted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isMuted ? Colors.grey[400] : AppTheme.gold,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: (isSending || isMuted) ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black87),
                )
              : const Icon(Icons.send_rounded, color: Colors.black87, size: 18),
        ),
      ),
    );
  }
}
