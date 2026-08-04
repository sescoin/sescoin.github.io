import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/ban_guard.dart';
import '../../common/date_utils.dart';
import '../../common/dispose_scope.dart';
import '../../common/keyboard_fix.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/chat_message.dart';
import '../../models/chat_read.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/service_providers.dart';

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
      // Le bouton d'infos change de contenu (et pulse) selon l'onglet actif.
      _tabController!.addListener(() {
        if (mounted) setState(() {});
      });
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

    final classesAsync = ref.watch(classListProvider);
    final userClassName = classesAsync.valueOrNull
            ?.where((c) => c.id == userClassId)
            .map((c) => c.name)
            .firstOrNull ??
        'Ma Classe';

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
          actions: [
            // Membres de la classe : accessible depuis l'onglet de classe,
            // là où la liste a du sens pour l'élève.
            if (_tabController!.index == 1)
              IconButton(
                icon: const Icon(Icons.groups_rounded),
                tooltip: 'Membres de la classe',
                onPressed: () =>
                    _showClassMembers(context, userClassId, userClassName),
              ),
            if (!isAdmin)
              _ChatInfoButton(classMode: _tabController!.index == 1),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(
                  text: 'Annonces',
                  icon: Icon(Icons.campaign_rounded, size: 18)),
              Tab(
                  text: userClassName,
                  icon: const Icon(Icons.school_rounded, size: 18)),
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
        actions: [if (!isAdmin) const _ChatInfoButton()],
      ),
      body: _GlobalChatBody(isAdmin: isAdmin),
    );
  }
}

// ── Bouton d'infos du chat (contenu selon l'onglet) ───────────────────────────

class _ChatInfoButton extends StatefulWidget {
  const _ChatInfoButton({this.classMode = false});

  /// true = onglet chat de classe, false = onglet Annonces.
  final bool classMode;

  @override
  State<_ChatInfoButton> createState() => _ChatInfoButtonState();
}

class _ChatInfoButtonState extends State<_ChatInfoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant _ChatInfoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le bouton pulsait à l'arrivée sur le chat de classe pour signaler que
    // son contenu changeait. L'effet attirait l'œil à chaque bascule
    // d'onglet sans rien apprendre de neuf : il est désactivé.
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: PressableScale(
        onTap: () {
          _pulseCtrl.stop();
          _pulseCtrl.value = 0;
          _show(context);
        },
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final t = _pulseCtrl.value;
            return Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color.lerp(
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.32),
                  t,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.3 + 0.5 * t),
                  width: 1 + t,
                ),
                boxShadow: t > 0
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45 * t),
                          blurRadius: 10 + 6 * t,
                        ),
                      ]
                    : null,
              ),
              child: Transform.scale(
                scale: 1 + 0.12 * t,
                child:
                    Icon(Icons.question_mark_rounded, size: 16, color: accent),
              ),
            );
          },
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final classMode = widget.classMode;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  classMode ? Icons.school_rounded : Icons.campaign_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                classMode ? 'Le chat de classe' : 'Le chat Annonces',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (classMode) ...[
                const _ChatInfoRow(
                  icon: Icons.chat_bubble_rounded,
                  text:
                      'Espace de discussion de la classe. Les messages inappropriés sont censurés automatiquement.',
                ),
                const SizedBox(height: 10),
                const _ChatInfoRow(
                  icon: Icons.add_circle_rounded,
                  text:
                      'Le bouton + permet de demander un prêt à la classe ou d\'envoyer un cadeau.',
                ),
                const SizedBox(height: 10),
                const _ChatInfoRow(
                  icon: Icons.card_giftcard_rounded,
                  text:
                      'Un cadeau revient au premier membre qui le récupère.',
                ),
              ] else ...[
                const _ChatInfoRow(
                  icon: Icons.admin_panel_settings_rounded,
                  text: 'Seul l\'administrateur peut publier des annonces ici.',
                ),
                const SizedBox(height: 10),
                const _ChatInfoRow(
                  icon: Icons.handshake_rounded,
                  text:
                      'Les demandes de prêt publiées ici sont visibles par tous les utilisateurs.',
                ),
                const SizedBox(height: 10),
                const _ChatInfoRow(
                  icon: Icons.card_giftcard_rounded,
                  text:
                      'Un cadeau envoyé par l\'administrateur revient au premier utilisateur qui le récupère.',
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatInfoRow extends StatelessWidget {
  const _ChatInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
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
      // Pas de bouton « Membres » ici : cet écran n'est atteint que depuis le
      // panneau admin, qui affiche déjà la liste des élèves de la classe.
      appBar: AppBar(title: Text(className)),
      body: _ClassChatBody(classId: classId, isAdmin: isAdmin),
    );
  }
}

/// Feuille listant les membres d'une classe (accessible à tout membre).
void _showClassMembers(BuildContext context, String classId, String className) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (context, scrollController) => Consumer(
        builder: (context, ref, _) {
          final membersAsync = ref.watch(classMembersProvider(classId));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, color: context.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Membres · $className',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger les membres.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucun membre.',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: members.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (context, i) {
                        final m = members[i];
                        return ListTile(
                          leading: UserAvatar(
                            username: m.username,
                            avatarUrl: m.avatarUrl,
                            radius: 20,
                          ),
                          title: Text(
                            m.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('@${m.username}'),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/user/${m.username}');
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
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
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _showScrollFab = false;
  bool _isNearBottom = true;
  final Set<String> _locallyDeletedIds = {};
  final Set<String> _locallyAcceptedLoanRequestIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
    if (color == Colors.red || color == AppTheme.negative) {
      AppFeedback.error(context, msg);
    } else if (color == Colors.orange || color == AppTheme.warning) {
      AppFeedback.warning(context, msg);
    } else {
      AppFeedback.success(context, msg);
    }
  }

  Future<void> _sendAdminMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    // Sur le web, garder le focus après l'envoi laisse un espace blanc là où
    // était le clavier lors d'un retour arrière : on ne re-focus que sur mobile.
    if (!kIsWeb) _focusNode.requestFocus();
    await ref.read(chatActionProvider.notifier).sendGlobalMessage(text);
    if (mounted && !kIsWeb) _focusNode.requestFocus();
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

  /// Menu admin sur une annonce : proposer d'abord Modifier ou Supprimer.
  void _showAdminAnnouncementActions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.7),
              ),
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
                  'Options de l\'annonce',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _ChatActionTile(
                  icon: Icons.edit_rounded,
                  label: 'Modifier',
                  onTap: () {
                    Navigator.pop(context);
                    _editAnnouncement(msg);
                  },
                ),
                const SizedBox(height: 8),
                _ChatActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _adminDeleteMessage(msg);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editAnnouncement(ChatMessage msg) async {
    final ctrl = TextEditingController(text: msg.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [ctrl],
        child: AppDialog(
          icon: Icons.edit_rounded,
          title: 'Modifier l\'annonce',
          subtitle: 'Visible par toute la classe',
          content: TextField(
            controller: ctrl,
            maxLength: 500,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Annonce',
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
      ),
    );
    if (!mounted) return;
    if (newContent == null ||
        newContent.isEmpty ||
        newContent == msg.content) {
      return;
    }
    try {
      await ref
          .read(chatActionProvider.notifier)
          .editGlobalMessage(msg.id, newContent);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _deleteOwnLoanRequest(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    if (ref.read(chatActionProvider).isMuted) {
      _showSnackBar(
        'Compte muet : suppression indisponible.',
        Colors.orange,
      );
      return;
    }
    setState(() => _locallyDeletedIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).deleteMessage(msg.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _acceptLoanRequest(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    if (msg.loanDueDate != null && msg.loanDueDate!.isBefore(DateTime.now())) {
      _showSnackBar(
        'Impossible d\'accepter : la date d\'échéance est déjà dépassée.',
        Colors.red,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Accepter le prêt'),
        content: Text(
          'Prêter ${msg.loanAmount?.toStringAsFixed(2) ?? '?'} SC à @${msg.username} ?'
          '${msg.loanInterestRate != null ? '\nTaux : ${msg.loanInterestRate}%' : ''}'
          '${msg.loanDueDate != null ? '\nÉchéance : ${_formatDueDate(msg.loanDueDate!)}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _locallyAcceptedLoanRequestIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).acceptChatLoanRequest(msg.id);
      if (!mounted) return;
      _showSnackBar('Prêt accepté.', AppTheme.positive);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyAcceptedLoanRequestIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  String _formatDueDate(DateTime dt) => _loanDueDateLabel(dt);

  Future<void> _claimGift(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    try {
      final amount =
          await ref.read(chatActionProvider.notifier).claimChatGift(msg.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _showSnackBar(
        'Cadeau récupéré : +${amount.toStringAsFixed(2)} SC.',
        AppTheme.positive,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        Colors.orange,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(globalMessagesProvider);
    final chatState = ref.watch(chatActionProvider);
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    // Compteurs quotidiens (annonces) pour afficher les limites.
    final allMsgs = messagesAsync.valueOrNull ?? const <ChatMessage>[];
    final giftsToday = allMsgs
        .where((m) =>
            m.isGift && m.userId == currentUserId && _isToday(m.createdAt))
        .length;
    final loansToday = allMsgs
        .where((m) =>
            m.isLoanRequest &&
            m.userId == currentUserId &&
            _isToday(m.createdAt))
        .length;

    return KeyboardDismissUnfocus(
        child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (messages) {
                  final visible = messages
                      .where((m) =>
                          !m.isDeleted && !_locallyDeletedIds.contains(m.id))
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
                        msg.createdAt.difference(prev.createdAt).inMinutes >=
                            15) {
                      items.add(_ChatItem.divider(msg.createdAt));
                    }
                    final showHeader =
                        prev == null || prev.userId != msg.userId;
                    items.add(_ChatItem.message(msg, showHeader: showHeader));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item.isDivider) {
                        return _TimeDivider(time: item.dividerTime!);
                      }
                      final msg = item.message!;
                      final isOwn = msg.userId == currentUserId;
                      final isAccepted = msg.isLoanRequestAccepted ||
                          _locallyAcceptedLoanRequestIds.contains(msg.id);
                      final canDelete = widget.isAdmin ||
                          (isOwn && msg.isLoanRequest && !isAccepted);

                      if (msg.isGift) {
                        return _GiftBubble(
                          message: msg,
                          isOwn: isOwn,
                          currentUserId: currentUserId,
                          showHeader: item.showHeader,
                          onClaim: !isOwn && !msg.isGiftClaimed
                              ? () => _claimGift(msg)
                              : null,
                          onTapUsername: () =>
                              context.push('/user/${msg.username}'),
                        );
                      }

                      if (msg.isLoanRequest) {
                        return _LoanRequestBubble(
                          message: msg,
                          isOwn: isOwn,
                          isAccepted: isAccepted,
                          showHeader: item.showHeader,
                          onDelete: canDelete
                              ? () => widget.isAdmin
                                  ? _adminDeleteMessage(msg)
                                  : _deleteOwnLoanRequest(msg)
                              : null,
                          onAccept: !isOwn && !isAccepted
                              ? () => _acceptLoanRequest(msg)
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
                        showEditedLabel: false,
                        onTapUsername: () =>
                            context.push('/user/${msg.username}'),
                        onLongPress: widget.isAdmin
                            ? () => _showAdminAnnouncementActions(msg)
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
                focusNode: _focusNode,
                chatState: chatState,
                onSend: _sendAdminMessage,
                hintText: 'Écrire une annonce…',
                leading: _AttachIconButton(
                  icon: Icons.card_giftcard_rounded,
                  tooltip: 'Envoyer un cadeau',
                  onTap: () => _showGiftDialog(context, ref, classId: null),
                ),
              )
            else
              _LoanRequestBar(
                loanUsed: loansToday,
                loanMax: 1,
                giftUsed: giftsToday,
                giftMax: 2,
                onTap: () {
                  if (!ensureNotBanned(context, ref)) return;
                  if (loansToday >= 1) {
                    _showSnackBar(
                      'Limite atteinte : une demande de prêt par jour.',
                      Colors.orange,
                    );
                    return;
                  }
                  context.push(
                    AppRoutes.loanCreate,
                    extra: {'chatMode': true},
                  );
                },
                onGift: () {
                  if (!ensureNotBanned(context, ref)) return;
                  if (giftsToday >= 2) {
                    _showSnackBar(
                      'Limite atteinte : deux cadeaux par jour.',
                      Colors.orange,
                    );
                    return;
                  }
                  _showGiftDialog(context, ref, classId: null);
                },
              ),
          ],
        ),
        if (_showScrollFab)
          Positioned(
            bottom: 72,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: context.accent,
              foregroundColor: context.onAccent,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    ));
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
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _muteTimer;
  bool _showScrollFab = false;
  bool _isNearBottom = true;
  final Set<String> _locallyDeletedIds = {};
  final Set<String> _locallyAcceptedLoanRequestIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
    if (color == Colors.red || color == AppTheme.negative) {
      AppFeedback.error(context, msg);
    } else if (color == Colors.orange || color == AppTheme.warning) {
      AppFeedback.warning(context, msg);
    } else {
      AppFeedback.success(context, msg);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!ensureNotBanned(context, ref)) return;

    ref.read(chatActionProvider.notifier).clearMuteIfExpired();
    if (ref.read(chatActionProvider).isMuted) return;

    _controller.clear();
    // Web : pas de re-focus (évite l'espace blanc du clavier au retour arrière).
    if (!kIsWeb) _focusNode.requestFocus();
    final result = await ref
        .read(chatActionProvider.notifier)
        .sendClassMessage(widget.classId, text);

    if (mounted && !kIsWeb) _focusNode.requestFocus();
    if (!mounted || result == null) return;
    if (result.warning) {
      final remaining = 3 - result.warningCount;
      if (result.muted) {
        _showSnackBar(
          'Compte rendu muet 10 minutes pour comportement inapproprié.',
          Colors.red,
        );
        _startMuteTimer();
      } else {
        _showSnackBar(
          'Avertissement ${result.warningCount}/3 — message censuré.'
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

  // ── Prêts et cadeaux de classe ─────────────────────────────────────────────

  Future<void> _acceptLoanRequest(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    if (msg.loanDueDate != null && msg.loanDueDate!.isBefore(DateTime.now())) {
      _showSnackBar(
        'Impossible d\'accepter : la date d\'échéance est déjà dépassée.',
        Colors.red,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Accepter le prêt'),
        content: Text(
          'Prêter ${msg.loanAmount?.toStringAsFixed(2) ?? '?'} SC à @${msg.username} ?'
          '${msg.loanInterestRate != null ? '\nTaux : ${msg.loanInterestRate}%' : ''}'
          '${msg.loanDueDate != null ? '\nÉchéance : ${_loanDueDateLabel(msg.loanDueDate!)}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _locallyAcceptedLoanRequestIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).acceptChatLoanRequest(msg.id);
      if (!mounted) return;
      _showSnackBar('Prêt accepté.', AppTheme.positive);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyAcceptedLoanRequestIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _deleteOwnLoanRequest(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    if (ref.read(chatActionProvider).isMuted) {
      _showSnackBar(
        'Compte muet : suppression indisponible.',
        Colors.orange,
      );
      return;
    }
    setState(() => _locallyDeletedIds.add(msg.id));
    try {
      await ref.read(chatActionProvider.notifier).deleteMessage(msg.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(msg.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  Future<void> _claimGift(ChatMessage msg) async {
    if (!ensureNotBanned(context, ref)) return;
    try {
      final amount =
          await ref.read(chatActionProvider.notifier).claimChatGift(msg.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _showSnackBar(
        'Cadeau récupéré : +${amount.toStringAsFixed(2)} SC.',
        AppTheme.positive,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        Colors.orange,
      );
    }
  }

  void _showAttachSheet() {
    if (!ensureNotBanned(context, ref)) return;
    final theme = Theme.of(context);
    // Compteurs quotidiens (classe) : cadeaux 3/jour, prêts 2/jour.
    final myId = ref.read(currentUserIdProvider) ?? '';
    final classMsgs =
        ref.read(classMessagesProvider(widget.classId)).valueOrNull ??
            const <ChatMessage>[];
    final giftsToday = classMsgs
        .where(
            (m) => m.isGift && m.userId == myId && _isToday(m.createdAt))
        .length;
    final loansToday = classMsgs
        .where((m) =>
            m.isLoanRequest && m.userId == myId && _isToday(m.createdAt))
        .length;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                'Partager avec la classe',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (!widget.isAdmin) ...[
                _ChatActionTile(
                  icon: Icons.handshake_rounded,
                  label: 'Demander un prêt',
                  badge: '$loansToday/2',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (loansToday >= 2) {
                      _showSnackBar(
                        'Limite atteinte : deux demandes de prêt par jour.',
                        Colors.orange,
                      );
                      return;
                    }
                    context.push(
                      AppRoutes.loanCreate,
                      extra: {'chatMode': true, 'classId': widget.classId},
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              _ChatActionTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Envoyer un cadeau',
                badge: widget.isAdmin ? null : '$giftsToday/3',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (!widget.isAdmin && giftsToday >= 3) {
                    _showSnackBar(
                      'Limite atteinte : trois cadeaux par jour.',
                      Colors.orange,
                    );
                    return;
                  }
                  _showGiftDialog(context, ref, classId: widget.classId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final ctrl = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => DisposeScope(
        disposables: [ctrl],
        child: AppDialog(
          icon: Icons.edit_rounded,
          title: 'Modifier le message',
          subtitle: 'La mention « modifié » sera ajoutée',
          content: TextField(
            controller: ctrl,
            maxLength: 500,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Message',
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
      ),
    );
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
          'Compte rendu muet 10 minutes pour comportement inapproprié.',
          Colors.red,
        );
      } else if (result.warning) {
        final remaining = 3 - result.warningCount;
        _showSnackBar(
          'Avertissement ${result.warningCount}/3 — message censuré.'
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
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        tone: AppDialogTone.danger,
        title: 'Supprimer le message ?',
        subtitle: 'Cette action est définitive',
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
        await ref
            .read(chatActionProvider.notifier)
            .adminDeleteMessage(message.id);
      } else {
        await ref.read(chatActionProvider.notifier).deleteMessage(message.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _locallyDeletedIds.remove(message.id));
      _showSnackBar('Erreur : $e', Colors.red);
    }
  }

  /// Transmet un message à l'administration.
  Future<void> _reportMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: Icons.flag_rounded,
        tone: AppDialogTone.danger,
        title: 'Signaler ce message ?',
        subtitle: '@${message.username}',
        content: const Text(
          'Le message sera transmis à l\'administration, qui décidera de la '
          'suite à donner. Un même message ne peut être signalé qu\'une fois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatServiceProvider).reportMessage(message.id);
      if (mounted) {
        AppFeedback.success(context, 'Signalement transmis.');
      }
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    }
  }

  void _showMessageActions(
      BuildContext context, ChatMessage message, bool isOwn) {
    // Un compte muet ne peut ni modifier ni supprimer ses messages.
    if (!widget.isAdmin && ref.read(chatActionProvider).isMuted) {
      _showSnackBar(
        'Compte muet : modification et suppression indisponibles.',
        Colors.orange,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
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
              color: theme.cardColor,
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
                // On ne signale pas ses propres messages : la RPC le refuse
                // de toute façon.
                if (!isOwn) ...[
                  _ChatActionTile(
                    icon: Icons.flag_outlined,
                    label: 'Signaler',
                    color: AppTheme.warning,
                    onTap: () {
                      Navigator.pop(context);
                      _reportMessage(message);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
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

    return KeyboardDismissUnfocus(
        child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (messages) {
                  final visible = messages
                      .where((m) =>
                          !m.isDeleted && !_locallyDeletedIds.contains(m.id))
                      .toList();

                  if (visible.isEmpty) {
                    return const _EmptyChat(
                      message: 'Aucun message pour l\'instant.',
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
                        msg.createdAt.difference(prev.createdAt).inMinutes >=
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item.isDivider) {
                        return _TimeDivider(time: item.dividerTime!);
                      }
                      final msg = item.message!;
                      final isOwn = msg.userId == currentUserId;

                      if (msg.isGift) {
                        return _GiftBubble(
                          message: msg,
                          isOwn: isOwn,
                          currentUserId: currentUserId,
                          showHeader: item.showHeader,
                          onClaim: !isOwn && !msg.isGiftClaimed
                              ? () => _claimGift(msg)
                              : null,
                          onTapUsername: () =>
                              context.push('/user/${msg.username}'),
                        );
                      }

                      if (msg.isLoanRequest) {
                        final isAccepted = msg.isLoanRequestAccepted ||
                            _locallyAcceptedLoanRequestIds.contains(msg.id);
                        final canDelete = widget.isAdmin ||
                            (isOwn && !isAccepted);
                        return _LoanRequestBubble(
                          message: msg,
                          isOwn: isOwn,
                          isAccepted: isAccepted,
                          showHeader: item.showHeader,
                          onDelete: canDelete
                              ? () => widget.isAdmin
                                  ? _deleteMessage(msg)
                                  : _deleteOwnLoanRequest(msg)
                              : null,
                          onAccept: !isOwn && !isAccepted
                              ? () => _acceptLoanRequest(msg)
                              : null,
                          onTapUsername: () =>
                              context.push('/user/${msg.username}'),
                        );
                      }

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
                            ? () => _showMessageActions(context, msg, isOwn)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(
              controller: _controller,
              focusNode: _focusNode,
              chatState: chatState,
              onSend: _send,
              hintText: 'Écrire un message…',
              leading: _AttachIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Prêt ou cadeau',
                onTap: _showAttachSheet,
              ),
            ),
          ],
        ),
        if (_showScrollFab)
          Positioned(
            bottom: 72,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: context.accent,
              foregroundColor: context.onAccent,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    ));
  }
}

// ── Barre demande de prêt (utilisateurs dans le chat global) ──────────────────

class _LoanRequestBar extends StatelessWidget {
  const _LoanRequestBar({
    required this.onTap,
    this.onGift,
    this.loanUsed = 0,
    this.loanMax = 1,
    this.giftUsed = 0,
    this.giftMax = 2,
  });

  final VoidCallback onTap;

  /// Si fourni, ajoute un bouton cadeau à côté de la demande de prêt.
  final VoidCallback? onGift;

  final int loanUsed;
  final int loanMax;
  final int giftUsed;
  final int giftMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final giftReached = giftUsed >= giftMax;
    final loanReached = loanUsed >= loanMax;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (onGift != null) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressableScale(
                      onTap: onGift,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(
                              alpha: giftReached ? 0.06 : 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accent.withValues(
                                alpha: giftReached ? 0.15 : 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: accent
                              .withValues(alpha: giftReached ? 0.4 : 1),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$giftUsed/$giftMax',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: giftReached
                            ? AppTheme.negative
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressableScale(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: loanReached
                                ? [
                                    accent.withValues(alpha: 0.4),
                                    accent.withValues(alpha: 0.3),
                                  ]
                                : [
                                    accent,
                                    Color.lerp(accent, Colors.black, 0.22)!
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: loanReached
                              ? null
                              : [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.32),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.handshake_rounded,
                                color: onAccent, size: 19),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Demande de prêt',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: onAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: onAccent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$loanUsed/$loanMax',
                                style: TextStyle(
                                  color: onAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    required this.isAccepted,
    required this.showHeader,
    required this.onTapUsername,
    this.onDelete,
    this.onAccept,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool isAccepted;
  final bool showHeader;
  final VoidCallback onTapUsername;
  final VoidCallback? onDelete;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    // Échéance dépassée sans acceptation : la demande n'est plus acceptable.
    final isExpiredDue = !isAccepted &&
        message.loanDueDate != null &&
        message.loanDueDate!.isBefore(DateTime.now());

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
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bandeau d'en-tête teinté
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.handshake_rounded,
                          color: onAccent,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demande de prêt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.negative.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: AppTheme.negative,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            message.loanAmount?.toStringAsFixed(0) ?? '?',
                            style: TextStyle(
                              fontSize: 26,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'SC',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: accent.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isAccepted ||
                          message.loanInterestRate != null ||
                          message.loanDueDate != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isAccepted)
                              const _LoanTag(
                                icon: Icons.check_circle_rounded,
                                label: 'Acceptée',
                                color: AppTheme.positive,
                              ),
                            if (message.loanInterestRate != null)
                              _LoanTag(
                                icon: Icons.percent_rounded,
                                label:
                                    '${message.loanInterestRate!.toStringAsFixed(message.loanInterestRate! % 1 == 0 ? 0 : 1)}% d\'intérêt',
                              ),
                            if (message.loanDueDate != null)
                              _LoanTag(
                                icon: Icons.event_rounded,
                                label: _loanDueDateLabel(message.loanDueDate!),
                              ),
                          ],
                        ),
                      ],
                      if (message.loanNote != null &&
                          message.loanNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          message.loanNote!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (isExpiredDue) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_off_rounded,
                                size: 15,
                                color: accent.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Expirée',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: accent.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (onAccept != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onAccept,
                            icon: const Icon(Icons.handshake_rounded, size: 16),
                            label: const Text('Accepter le prêt'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: TextStyle(
                                fontFamily: context.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _loanDueDateLabel(DateTime dt) => formatLoanDueDateLabel(dt);

// ── Tag compact (taux, échéance) dans une bulle de demande de prêt ────────────

class _LoanTag extends StatelessWidget {
  const _LoanTag({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;

  /// null = couleur d'accent du thème.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton rond à gauche de la barre de saisie ────────────────────────────────

class _AttachIconButton extends StatelessWidget {
  const _AttachIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: accent, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Envoi d'un cadeau ─────────────────────────────────────────────────────────

/// Vrai si la date est dans la journée courante (pour les limites/jour).
bool _isToday(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  return local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
}

Future<void> _showGiftDialog(
  BuildContext context,
  WidgetRef ref, {
  String? classId,
}) async {
  if (!ensureNotBanned(context, ref)) return;
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => DisposeScope(
      disposables: [amountCtrl, noteCtrl],
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Envoyer un cadeau',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: 'SC',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Raison (optionnelle)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.card_giftcard_rounded, size: 17),
                      label: const Text('Envoyer'),
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

  final amount =
      double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  final note = noteCtrl.text.trim();

  if (confirmed != true) return;
  // Le solde est stocké à 2 décimales : un cadeau doit valoir au moins 0,01 SC,
  // sinon il s'affiche « 0.00 » et sa récupération est refusée par la base.
  if (amount < 0.01) {
    if (context.mounted) {
      AppFeedback.warning(context, 'Le cadeau doit valoir au moins 0,01 SC.');
    }
    return;
  }

  final result = await ref.read(chatActionProvider.notifier).sendChatGift(
        amount,
        note: note.isEmpty ? null : note,
        classId: classId,
      );
  if (!context.mounted) return;
  if (result == null) {
    final error = ref.read(chatActionProvider).error?.trim();
    AppFeedback.error(
      context,
      error == null || error.isEmpty ? 'L\'envoi a échoué.' : error,
    );
  } else {
    AppFeedback.success(context, 'Cadeau envoyé.');
  }
}

// ── Bulle cadeau ──────────────────────────────────────────────────────────────

class _GiftBubble extends StatelessWidget {
  const _GiftBubble({
    required this.message,
    required this.isOwn,
    required this.currentUserId,
    required this.showHeader,
    required this.onTapUsername,
    this.onClaim,
  });

  final ChatMessage message;
  final bool isOwn;
  final String currentUserId;
  final bool showHeader;
  final VoidCallback onTapUsername;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final claimed = message.isGiftClaimed;
    final claimedByMe = message.giftClaimedBy == currentUserId;
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
            decoration: BoxDecoration(
              gradient: claimed
                  ? null
                  : LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: claimed ? theme.cardColor : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: claimed
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.10)
                    : accent.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: claimed
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: claimed
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.12)
                            : accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: claimed
                            ? theme.colorScheme.onSurfaceVariant
                            : onAccent,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cadeau',
                        style: TextStyle(
                          color: claimed
                              ? theme.colorScheme.onSurfaceVariant
                              : accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.giftAmount?.toStringAsFixed(
                            (message.giftAmount ?? 0) % 1 == 0 ? 0 : 2,
                          ) ??
                          '?',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: claimed
                            ? theme.colorScheme.onSurfaceVariant
                            : accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'SC',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: (claimed
                                  ? theme.colorScheme.onSurfaceVariant
                                  : accent)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                if (message.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (claimed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.positive.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppTheme.positive,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            claimedByMe
                                ? 'Cadeau récupéré'
                                : 'Récupéré par @${message.giftClaimedUsername ?? '?'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.positive,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (onClaim != null)
                  _ClaimGiftButton(onTap: onClaim!)
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'En attente de récupération…',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Récupérer » : pulse en continu pour attirer l'œil.
class _ClaimGiftButton extends StatefulWidget {
  const _ClaimGiftButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClaimGiftButton> createState() => _ClaimGiftButtonState();
}

class _ClaimGiftButtonState extends State<_ClaimGiftButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!AppMotion.reduce) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Transform.scale(
          scale: 1 + 0.03 * t,
          child: PressableScale(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent,
                    Color.lerp(accent, Colors.black, 0.22)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35 + 0.2 * t),
                    blurRadius: 12 + 8 * t,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.redeem_rounded, color: onAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Récupérer',
                    style: TextStyle(
                      color: onAccent,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Petit compteur de limite (ex. « 1/3 ») affiché à droite.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.onSurface;
    // Largeur forcée : dans une Column, chaque tuile prendrait sinon sa
    // largeur intrinsèque et les chevrons ne seraient plus alignés d'une
    // ligne à l'autre.
    return SizedBox(
      width: double.infinity,
      child: Material(
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
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: actionColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: actionColor,
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: actionColor.withValues(alpha: 0.55),
                ),
              ],
            ),
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
    this.showEditedLabel = true,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showHeader;
  final List<ChatRead> readers;
  final VoidCallback onTapUsername;
  final VoidCallback? onLongPress;

  /// Affiche « (modifié) » sous le message. Désactivé pour les annonces.
  final bool showEditedLabel;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return const SizedBox.shrink();

    final timeStr = DateFormat('HH:mm').format(message.createdAt);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCensored = message.isCensored;

    final accent = theme.colorScheme.primary;
    final bubbleColor = isCensored
        ? (isDark ? Colors.grey[800]! : Colors.grey[300]!)
        : isOwn
            ? accent
            : (isDark ? theme.cardColor : Colors.white);

    final textColor = isCensored
        ? Colors.grey
        : isOwn
            ? theme.colorScheme.onPrimary
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      // Léger dégradé sur ses propres messages : la bulle
                      // prend du relief sans nuire à la lisibilité.
                      gradient: isOwn && !isCensored
                          ? LinearGradient(
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.black, 0.18)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isOwn && !isCensored ? null : bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isOwn ? 18 : 5),
                        bottomRight: Radius.circular(isOwn ? 5 : 18),
                      ),
                      border: isCensored
                          ? Border.all(
                              color: AppTheme.negative.withValues(alpha: 0.45),
                              width: 1.1,
                            )
                          : (!isOwn && !isDark)
                              // Contour discret : sans lui, une bulle blanche
                              // se fond dans un fond clair.
                              ? Border.all(
                                  color: Colors.black.withValues(alpha: 0.06),
                                )
                              : null,
                      boxShadow: [
                        BoxShadow(
                          color: isOwn && !isCensored
                              ? accent.withValues(alpha: 0.26)
                              : Colors.black
                                  .withValues(alpha: isDark ? 0.26 : 0.06),
                          blurRadius: isOwn ? 12 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isCensored
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14.2,
                                    height: 1.35,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            message.content,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.6,
                              height: 1.38,
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
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (showEditedLabel && message.editedAt != null) ...[
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

/// Vrai lorsque la saisie se fait au clavier physique plutôt qu'au clavier
/// tactile.
///
/// `defaultTargetPlatform` reste fiable sur le web : Flutter y déduit la
/// plateforme de l'agent utilisateur, un téléphone sous navigateur est donc
/// bien reconnu comme mobile.
bool get _hasPhysicalKeyboard => switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia =>
        false,
      _ => true,
    };

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.chatState,
    required this.onSend,
    required this.hintText,
    this.focusNode,
    this.leading,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ChatState chatState;
  final VoidCallback onSend;
  final String hintText;

  /// Bouton optionnel à gauche du champ (cadeau, pièce jointe…).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isMuted = chatState.isMuted;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMuted)
          Container(
            width: double.infinity,
            color: AppTheme.warning.withValues(alpha: 0.13),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.volume_off_rounded,
                  color: AppTheme.warning,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compte muet — comportement inapproprié détecté.',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? Colors.black12,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.inputDecorationTheme.fillColor
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(21),
                        // Liseré d'accent : le champ se détache du fond au
                        // lieu de flotter sans limite visible.
                        border: Border.all(
                          color: context.accent.withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                      ),
                      child: Focus(
                        // Avec un clavier physique, Entrée envoie et
                        // Maj+Entrée passe à la ligne. Sur mobile, Entrée doit
                        // rester un retour à la ligne : l'envoi passe alors
                        // uniquement par le bouton.
                        onKeyEvent: (node, event) {
                          if (!_hasPhysicalKeyboard) {
                            return KeyEventResult.ignored;
                          }
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            onSend();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: !isMuted,
                          maxLength: 500,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: isMuted ? 'Compte muet…' : hintText,
                            counterText: '',
                            // Le contour appartient au Container parent. Sans
                            // neutraliser aussi enabled/focused/disabled, le
                            // thème global redessine son propre cadre par
                            // dessus, avec un rayon différent.
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
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
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final disabled = isSending || isMuted;

    return AnimatedContainer(
      duration: AppMotion.duration(const Duration(milliseconds: 200)),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: disabled
            ? null
            : LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.24)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: disabled
            ? theme.colorScheme.onSurface.withValues(alpha: 0.14)
            : null,
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: isSending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onAccent,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: isMuted
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : onAccent,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }
}
