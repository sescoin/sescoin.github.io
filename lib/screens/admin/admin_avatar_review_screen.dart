import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                                child: Column(
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
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _showFullPhoto(
                                          context, pendingAvatarUrl),
                                      child: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 18,
                                        color: AppTheme.gold,
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

  void _showFullPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image_rounded, size: 40)),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Fermer'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Photo approuvée' : 'Photo refusée'),
          backgroundColor: approve ? AppTheme.positive : AppTheme.negative,
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
