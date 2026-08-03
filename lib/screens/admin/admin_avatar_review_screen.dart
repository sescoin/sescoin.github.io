import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/app_feedback.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/profile_provider.dart';

class AdminAvatarReviewScreen extends ConsumerWidget {
  const AdminAvatarReviewScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));
    final actionState = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: actionState.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Validation de photo')),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorRetry(
            message: error.toString(),
            onRetry: () => ref.invalidate(profileByIdProvider(userId)),
          ),
          data: (profile) {
            final pendingAvatarUrl = profile.pendingAvatarUrl;
            if (pendingAvatarUrl == null || pendingAvatarUrl.isEmpty) {
              return const Center(
                child: Text('Aucune photo en attente pour ce compte'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _AvatarPanel(
                                label: 'Photo actuelle',
                                child: Center(
                                  child: UserAvatar(
                                    username: profile.username,
                                    avatarUrl: profile.avatarUrl,
                                    radius: 52,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AvatarPanel(
                                label: 'Nouvelle photo',
                                // Pastille d'agrandissement posée dans l'angle
                                // de la photo, comme sur les demandes de
                                // compte.
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Image.network(
                                          pendingAvatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.04),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.white54,
                                              size: 36,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: GestureDetector(
                                        onTap: () => _showFullPhoto(
                                          context,
                                          pendingAvatarUrl,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: context.accent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.28),
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: profileAsync.valueOrNull?.pendingAvatarUrl?.isNotEmpty ==
                true
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actionState.isLoading
                            ? null
                            : () => _handleDecision(
                                  context,
                                  ref,
                                  approve: false,
                                ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.negative,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: actionState.isLoading
                            ? null
                            : () => _handleDecision(
                                  context,
                                  ref,
                                  approve: true,
                                ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approuver'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  /// Photo en plein cadre, avec fermeture flottante — même présentation que
  /// l'aperçu des demandes de compte.
  void _showFullPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (d) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                url,
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
                      size: 19,
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

  Future<void> _handleDecision(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    try {
      if (approve) {
        await ref.read(adminActionsProvider.notifier).approveAvatarChange(userId);
      } else {
        await ref.read(adminActionsProvider.notifier).rejectAvatarChange(userId);
      }
      ref.invalidate(profileByIdProvider(userId));
      if (!context.mounted) {
        return;
      }
      if (approve) {
        AppFeedback.success(context, 'Photo approuvée.');
      } else {
        AppFeedback.info(context, 'Photo refusée.');
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppFeedback.error(context, error);
    }
  }
}

class _AvatarPanel extends StatelessWidget {
  const _AvatarPanel({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
