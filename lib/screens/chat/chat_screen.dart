import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _muteTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatActionProvider.notifier).clearMuteIfExpired();
    final chatState = ref.read(chatActionProvider);
    if (chatState.isMuted) return;

    _controller.clear();
    final result = await ref.read(chatActionProvider.notifier).sendMessage(text);

    if (!mounted) return;

    if (result == null) {
      // Erreur (muet, banni, etc.) — affichée via chatState.error
      return;
    }

    if (result.warning) {
      final remaining = 3 - result.warningCount;
      if (result.muted) {
        _showSnackBar(
          '🔇 Vous avez été muet pendant 10 minutes pour comportement inapproprié.',
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
    _muteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(chatActionProvider.notifier).clearMuteIfExpired();
      if (!ref.read(chatActionProvider).isMuted) {
        _muteTimer?.cancel();
      }
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

    ref.listen(chatMessagesProvider, (_, next) {
      if (next.hasValue) _scrollToBottom();
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
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun message pour l\'instant.\nSoyez le premier à écrire !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isOwn = msg.userId == currentUserId;
                    final showHeader = index == 0 ||
                        messages[index - 1].userId != msg.userId;
                    return _MessageBubble(
                      message: msg,
                      isOwn: isOwn,
                      showHeader: showHeader,
                      onTapUsername: () =>
                          context.push('/user/${msg.username}'),
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
          '• Les messages sont visibles par tous.',
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showHeader,
    required this.onTapUsername,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showHeader;
  final VoidCallback onTapUsername;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = message.isCensored
        ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
        : isOwn
            ? AppTheme.gold
            : (isDark ? const Color(0xFF2A2A3E) : Colors.white);

    final textColor = message.isCensored
        ? Colors.grey
        : isOwn
            ? Colors.black87
            : theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(
        top: showHeader ? 12 : 2,
        bottom: 2,
      ),
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
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOwn ? 16 : 4),
                      bottomRight: Radius.circular(isOwn ? 4 : 16),
                    ),
                    border: message.isCensored
                        ? Border.all(color: Colors.red.withValues(alpha: 0.4))
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontStyle: message.isCensored
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (isOwn) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorMsg != null)
          Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              errorMsg,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (isMuted)
          Container(
            width: double.infinity,
            color: Colors.orange.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.volume_off_rounded,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Vous êtes muet — comportement inapproprié détecté.',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isMuted && !chatState.isSending,
                    maxLength: 500,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: isMuted
                          ? 'Vous êtes muet…'
                          : 'Écrire un message…',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
      ],
    );
  }
}

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: isMuted
            ? Colors.grey
            : AppTheme.gold,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: (isSending || isMuted) ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black87,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.black87,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
