import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/chat_read.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _muteTimer;
  String? _lastReadId;
  bool _showScrollFab = false;

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
    _muteTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final distFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.offset;
    final should = distFromBottom > 180;
    if (should != _showScrollFab) setState(() => _showScrollFab = should);
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

  Future<void> _markRead(String messageId) async {
    if (_lastReadId == messageId) return;
    _lastReadId = messageId;
    await ref.read(chatActionProvider.notifier).markRead(messageId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatActionProvider.notifier).clearMuteIfExpired();
    if (ref.read(chatActionProvider).isMuted) return;

    _controller.clear();
    final result =
        await ref.read(chatActionProvider.notifier).sendMessage(text);

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

  Future<void> _editMessage(ChatMessage message) async {
    final ctrl = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: ctrl,
          maxLength: 500,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
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
      await ref
          .read(chatActionProvider.notifier)
          .editMessage(message.id, newContent);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message ?'),
        content:
            const Text('Cette action est définitive.'),
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

    try {
      await ref
          .read(chatActionProvider.notifier)
          .deleteMessage(message.id);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  void _showMessageActions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Supprimer',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startMuteTimer() {
    _muteTimer?.cancel();
    _muteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(chatActionProvider.notifier).clearMuteIfExpired();
      if (!ref.read(chatActionProvider).isMuted) _muteTimer?.cancel();
      if (mounted) setState(() {});
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);
    final chatState = ref.watch(chatActionProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final readsMap = ref.watch(chatReadsMapProvider);

    ref.listen(chatMessagesProvider, (_, next) {
      if (next.hasValue && next.value!.isNotEmpty) {
        _scrollToBottom();
        _markRead(next.value!.last.id);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat de classe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showRulesDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erreur : $e')),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return _EmptyChat();
                    }
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());

                    // Construire la liste d'items (messages + séparateurs)
                    final items = <_ChatItem>[];
                    for (int i = 0; i < messages.length; i++) {
                      final msg = messages[i];
                      final prev = i > 0 ? messages[i - 1] : null;
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
                        return _MessageBubble(
                          message: msg,
                          isOwn: isOwn,
                          showHeader: item.showHeader,
                          readers: item.readers,
                          onTapUsername: () =>
                              context.push('/user/${msg.username}'),
                          onLongPress: isOwn && !msg.isDeleted
                              ? () => _showMessageActions(context, msg)
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
              ),
            ],
          ),
          // Bouton scroll vers le bas
          if (_showScrollFab)
            Positioned(
              bottom: 80,
              right: 16,
              child: AnimatedScale(
                scale: _showScrollFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  onPressed: _scrollToBottom,
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black87,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Règles du chat'),
        content: const Text(
          '• Respectez les autres membres.\n'
          '• Les insultes et menaces sont automatiquement censurées.\n'
          '• 3 avertissements = 10 minutes de mute.\n'
          '• Les messages disparaissent automatiquement après 48h.\n'
          '• Appuyez longtemps sur vos messages pour les modifier ou supprimer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

// ── Modèle interne pour les items de liste ────────────────────────────────────

class _ChatItem {
  _ChatItem._({
    this.message,
    this.dividerTime,
    this.showHeader = false,
    this.readers = const [],
  });

  factory _ChatItem.divider(DateTime time) =>
      _ChatItem._(dividerTime: time);

  factory _ChatItem.message(
    ChatMessage msg, {
    required bool showHeader,
    required List<ChatRead> readers,
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
            'Aucun message pour l\'instant.',
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Soyez le premier à écrire !',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isDeleted = message.isDeleted;
    final isCensored = message.isCensored && !isDeleted;

    final bubbleColor = isDeleted
        ? (isDark ? Colors.grey[850]! : Colors.grey[200]!)
        : isCensored
            ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
            : isOwn
                ? AppTheme.gold
                : (isDark ? const Color(0xFF2A2A3E) : Colors.white);

    final textColor = isDeleted
        ? Colors.grey[500]!
        : isCensored
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
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isOwn ? 18 : 4),
                        bottomRight: Radius.circular(isOwn ? 4 : 18),
                      ),
                      border: isCensored
                          ? Border.all(
                              color: Colors.red.withValues(alpha: 0.35),
                              width: 1.2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isDeleted ? 'Message supprimé' : message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.5,
                        fontStyle: (isDeleted || isCensored)
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
                      if (message.editedAt != null && !isDeleted) ...[
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
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: child,
          ),
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
    const r = 7.0; // radius
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
        curve: Interval(start, end, curve: Curves.elasticOut),
      ),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: Curves.easeIn),
      ),
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
  });

  final TextEditingController controller;
  final ChatState chatState;
  final VoidCallback onSend;

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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(errorMsg,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        if (isMuted)
          Container(
            width: double.infinity,
            color: Colors.orange.withValues(alpha: 0.08),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.volume_off_rounded,
                    color: Colors.orange, size: 15),
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
            color: isDark
                ? const Color(0xFF1A1A2E)
                : theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
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
                            ? const Color(0xFF2A2A3E)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: controller,
                        enabled: !isMuted && !chatState.isSending,
                        maxLength: 500,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: isMuted
                              ? 'Vous êtes muet…'
                              : 'Écrire un message…',
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
              : const Icon(Icons.send_rounded,
                  color: Colors.black87, size: 18),
        ),
      ),
    );
  }
}
