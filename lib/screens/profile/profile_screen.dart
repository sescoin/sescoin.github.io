import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../loan/loan_card.dart';
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
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscure,
                decoration: const InputDecoration(labelText: 'Confirmer'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }
    if (newController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
        ),
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).changePasswordWithVerification(
            oldController.text,
            newController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe modifié !'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
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
      final bytes = await picked.readAsBytes();
      final path = 'pending/$userId.jpg';
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

      final profile = ref.read(currentProfileProvider).value;
      if (profile?.isAdmin == true) {
        await ref.read(profileServiceProvider).updateAvatar(userId, url);
      } else {
        await ref.read(profileServiceProvider).requestAvatarChange(userId, url);
      }
      await ref.read(currentProfileProvider.notifier).refresh();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profile?.isAdmin == true
                ? 'Photo de profil mise à jour !'
                : 'Photo envoyée, en attente d’approbation',
          ),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous serez redirigé vers la page de connexion.'),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rembourser le prêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Montant restant : ${loan.remainingAmount.toStringAsFixed(2)} SC',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant à rembourser',
                suffixText: 'SC',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rembourser'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final amount = double.tryParse(controller.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remboursement enregistré'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _confirmLoanAction({
    required String title,
    required String message,
    required Future<void> Function() action,
    String successMessage = 'Action effectuée',
  }) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteLoan(Loan loan) async {
    try {
      await ref.read(loanActionProvider.notifier).deleteLoan(loan.id);
      ref.invalidate(userLoansProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prêt supprimé')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification supprimée')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
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
                  onPressed: () => context.push(AppRoutes.transactionExplorer),
                  icon: const Icon(Icons.hub_rounded),
                  tooltip: 'Explorateur',
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      labelColor: AppTheme.gold,
                      tabs: const [
                        Tab(text: 'Prêts'),
                        Tab(text: 'Notifications'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        username: profile.username,
                        avatarUrl: profile.avatarUrl,
                        radius: 28,
                        onTap: onPhotoTap,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: onPhotoTap,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.black,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${profile.username}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.formattedBalance,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.gold,
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
                  child: const Text(
                    'Une nouvelle photo de profil est en attente d’approbation.',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onChangePassword,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Mot de passe'),
                ),
              ),
            ],
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

        final sortedLoans = [...loans]
          ..sort((a, b) {
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
              ...sortedLoans.map(
                (loan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoanCard(
                    loan: loan,
                    currentUserId: currentUserId,
                    isLoading: isLoading,
                    onAccept: loan.isPending ? () => onAccept(loan) : null,
                    onReject: loan.isPending ? () => onReject(loan) : null,
                    onRepay:
                        loan.isActive && !loan.isFullyRepaid ? () => onRepay(loan) : null,
                    onCancel: loan.isPending ? () => onCancel(loan) : null,
                    onDelete: loan.isArchived ? () => onDelete(loan) : null,
                  ),
                ),
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
  });

  final Future<void> Function(String notificationId) onDeleteNotification;

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
                          onTap: () async {
                            if (!notification.isRead) {
                              await ref
                                  .read(notificationActionsProvider.notifier)
                                  .markAsRead(notification.id);
                            }
                          },
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
