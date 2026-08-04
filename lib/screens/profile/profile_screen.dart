import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/animations.dart';
import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/ban_guard.dart';
import '../../common/dispose_scope.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../loan/loan_card.dart';
import '../../models/app_notification.dart';
import '../../models/loan.dart';
import '../../models/profile.dart';
import '../../notification/notification_tile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/service_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialTab.clamp(0, 1);
    if (oldWidget.initialTab != widget.initialTab &&
        _tabController.index != nextIndex) {
      _tabController.animateTo(nextIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    context.push(AppRoutes.changePassword);
  }

  Future<void> _requestPhotoChange() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final profile = ref.read(currentProfileProvider).value;
      final bytes = await picked.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = profile?.isAdmin == true
          ? 'profiles/$userId/$timestamp.jpg'
          : 'pending/$userId/$timestamp.jpg';
      await Supabase.instance.client.storage
          .from(AppConstants.bucketAvatars)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url = Supabase.instance.client.storage
          .from(AppConstants.bucketAvatars)
          .getPublicUrl(path);

      if (profile?.isAdmin == true) {
        final updated =
            await ref.read(profileServiceProvider).updateAvatar(userId, url);
        ref.read(currentProfileProvider.notifier).updateLocal(updated);
      } else {
        await ref.read(profileServiceProvider).requestAvatarChange(userId, url);
        final current = ref.read(currentProfileProvider).value;
        if (current != null) {
          ref.read(currentProfileProvider.notifier).updateLocal(
                current.copyWith(pendingAvatarUrl: url),
              );
        }
      }
      await ref.read(currentProfileProvider.notifier).refresh();

      if (!mounted) {
        return;
      }
      if (profile?.isAdmin == true) {
        AppFeedback.success(context, 'Photo de profil mise à jour !');
      } else {
        AppFeedback.info(
          context,
          'Photo envoyée ! Elle apparaîtra dès qu\'elle sera approuvée.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.logout_rounded,
        tone: AppDialogTone.danger,
        title: 'Se déconnecter ?',
        content: const Text('Retour à l\'écran de connexion.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negative,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentProfileProvider.notifier).signOut();
    }
  }

  Future<void> _handleLoanRepay(Loan loan) async {
    final controller = TextEditingController(
      text: loan.remainingAmount.toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DisposeScope(
        disposables: [controller],
        child: AppDialog(
          icon: Icons.payments_rounded,
          title: 'Rembourser le prêt',
          subtitle:
              'Restant : ${loan.remainingAmount.toStringAsFixed(2)} SC',
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant à rembourser',
              suffixText: 'SC',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Rembourser'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final amount = double.tryParse(controller.text.replaceAll(',', '.'));
    if (amount == null || amount < 0.01) {
      AppFeedback.warning(
        context,
        'Le remboursement doit valoir au moins 0,01 SC.',
      );
      return;
    }

    try {
      await ref.read(loanActionProvider.notifier).repayLoan(
            loanId: loan.id,
            amount: amount,
          );
      ref.invalidate(userLoansProvider);
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, 'Remboursement enregistré !');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }

  Future<void> _confirmLoanAction({
    required String title,
    required String message,
    required Future<void> Function() action,
    String successMessage = 'Action effectuée',
  }) async {
    if (!ensureNotBanned(context, ref)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await action();
      ref.invalidate(userLoansProvider);
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }

  Future<void> _deleteLoan(Loan loan) async {
    try {
      await ref.read(loanActionProvider.notifier).deleteLoan(loan.id);
      ref.invalidate(userLoansProvider);
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, 'Prêt supprimé.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await ref
          .read(notificationActionsProvider.notifier)
          .deleteNotification(notificationId);
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, 'Notification supprimée.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      await ref
          .read(notificationActionsProvider.notifier)
          .markAsRead(notification.id);
    }
    if (!mounted) {
      return;
    }

    if (notification.opensAvatarReview) {
      context.push(
        AppRoutes.adminAvatarReview.replaceFirst(
          ':userId',
          notification.targetUserId!,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final loanActionState = ref.watch(loanActionProvider);
    final notificationActions = ref.watch(notificationActionsProvider);
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: ErrorRetry(
          message: error.toString(),
          onRetry: () => ref.read(currentProfileProvider.notifier).refresh(),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return const SizedBox.shrink();
        }

        return LoadingOverlay(
          isLoading: loanActionState.isLoading || notificationActions.isLoading,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Profil'),
              actions: [
                IconButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Paramètres',
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.transactionExplorer),
                  icon: const Icon(Icons.hub_rounded),
                  tooltip: 'Blockchain',
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.leaderboard),
                  icon: const Icon(Icons.leaderboard_rounded),
                  tooltip: 'Classement',
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
            body: Column(
              children: [
                _ProfileHeader(
                  profile: profile,
                  onPhotoTap: _requestPhotoChange,
                  onChangePassword: _changePassword,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(14),
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.accent,
                            Color.lerp(context.accent, Colors.black, 0.20)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: context.accent.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      labelColor: context.onAccent,
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      tabs: [
                        const Tab(
                          height: 44,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_rounded, size: 16),
                                SizedBox(width: 7),
                                Text('Prêts'),
                              ],
                            ),
                          ),
                        ),
                        // FittedBox : l'arrivée du badge de non-lus allongeait
                        // la ligne au-delà de la largeur de l'onglet.
                        Tab(
                          height: 44,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 7),
                                const Text('Notifications'),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final unread = ref
                                            .watch(unreadCountProvider)
                                            .valueOrNull ??
                                        0;
                                    if (unread <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: AnimatedBadge(
                                        count: unread,
                                        color: AppTheme.info,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _LoansTab(
                        currentUserId: currentUserId,
                        onCreateLoan: () => context.push(AppRoutes.loanCreate),
                        onAccept: (loan) => _confirmLoanAction(
                          title: 'Accepter ce prêt ?',
                          message:
                              'Le montant sera envoyé à ${loan.borrowerUsername}.',
                          successMessage: 'Prêt accepté',
                          action: () => ref
                              .read(loanActionProvider.notifier)
                              .acceptLoan(loan.id),
                        ),
                        onReject: (loan) => _confirmLoanAction(
                          title: 'Refuser cette demande ?',
                          message:
                              'La demande de ${loan.borrowerUsername} sera refusée.',
                          successMessage: 'Demande refusée',
                          action: () => ref
                              .read(loanActionProvider.notifier)
                              .rejectLoan(loan.id),
                        ),
                        onCancel: (loan) => _confirmLoanAction(
                          title: 'Annuler cette demande ?',
                          message: 'Cette demande de prêt sera annulée.',
                          successMessage: 'Demande annulée',
                          action: () => ref
                              .read(loanActionProvider.notifier)
                              .cancelLoan(loan.id),
                        ),
                        onRepay: _handleLoanRepay,
                        onDelete: _deleteLoan,
                      ),
                      _NotificationsTab(
                        onDeleteNotification: _deleteNotification,
                        onOpenNotification: _openNotification,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onPhotoTap,
    required this.onChangePassword,
  });

  final Profile profile;
  final VoidCallback onPhotoTap;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: FadeSlideIn(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Color.lerp(Theme.of(context).cardColor, accent, 0.14)!,
                Theme.of(context).cardColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: UserAvatar(
                            username: profile.username,
                            avatarUrl: profile.avatarUrl,
                            radius: 30,
                            onTap: onPhotoTap,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: onPhotoTap,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).cardColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: AppTheme.onAccent(accent),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${profile.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Solde',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 1),
                          CountUpAmount(
                            value: profile.balance,
                            builder: (context, animated) => Text(
                              '${animated.toStringAsFixed(2)} SC',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.pendingAvatarUrl != null &&
                    profile.pendingAvatarUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 18,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nouvelle photo en attente d\'approbation.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onChangePassword,
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Mot de passe'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: accent.withValues(alpha: 0.4),
                      ),
                      foregroundColor: accent,
                      textStyle: TextStyle(
                        fontFamily: context.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoansTab extends ConsumerWidget {
  const _LoansTab({
    required this.currentUserId,
    required this.onCreateLoan,
    required this.onAccept,
    required this.onReject,
    required this.onRepay,
    required this.onCancel,
    required this.onDelete,
  });

  final String currentUserId;
  final VoidCallback onCreateLoan;
  final Future<void> Function(Loan loan) onAccept;
  final Future<void> Function(Loan loan) onReject;
  final Future<void> Function(Loan loan) onRepay;
  final Future<void> Function(Loan loan) onCancel;
  final Future<void> Function(Loan loan) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(userLoansProvider);
    final isLoading = ref.watch(loanActionProvider).isLoading;

    return loansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(
        message: 'Impossible de charger les prêts',
        onRetry: () => ref.invalidate(userLoansProvider),
      ),
      data: (loans) {
        if (loans.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const EmptyState(
                icon: Icons.handshake_rounded,
                title: 'Aucun prêt pour le moment',
                subtitle: 'Crée une demande pour commencer',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreateLoan,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Demander un prêt'),
              ),
            ],
          );
        }

        final sortedLoans = [...loans]..sort((a, b) {
            if (a.isArchived == b.isArchived) {
              return b.createdAt.compareTo(a.createdAt);
            }
            return a.isArchived ? 1 : -1;
          });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(userLoansProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreateLoan,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle demande de prêt'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prêts',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...sortedLoans.indexed.map(
                (entry) {
                  final (index, loan) = entry;
                  return FadeSlideIn.staggered(
                    key: ValueKey(loan.id),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LoanCard(
                        loan: loan,
                        currentUserId: currentUserId,
                        isLoading: isLoading,
                        onAccept: loan.isPending ? () => onAccept(loan) : null,
                        onReject: loan.isPending ? () => onReject(loan) : null,
                        onRepay: loan.isActive && !loan.isFullyRepaid
                            ? () => onRepay(loan)
                            : null,
                        onCancel: loan.isPending ? () => onCancel(loan) : null,
                        onDelete: loan.isArchived || loan.isExpiredPending
                            ? () => onDelete(loan)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab({
    required this.onDeleteNotification,
    required this.onOpenNotification,
  });

  final Future<void> Function(String notificationId) onDeleteNotification;
  final Future<void> Function(AppNotification notification) onOpenNotification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return notificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorRetry(
        message: 'Impossible de charger les notifications',
        onRetry: () => ref.invalidate(notificationsProvider),
      ),
      data: (notifications) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: notifications.isEmpty
                          ? null
                          : () => ref
                              .read(notificationActionsProvider.notifier)
                              .markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Tout vu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: notifications.isEmpty
                          ? null
                          : () => ref
                              .read(notificationActionsProvider.notifier)
                              .clearAll(),
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Tout supprimer'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: 'Aucune notification',
                        subtitle: 'Les nouveautés apparaîtront ici',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return NotificationTile(
                          notification: notification,
                          onTap: () => onOpenNotification(notification),
                          onDelete: () => onDeleteNotification(notification.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
