import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'app_feedback.dart';

/// Vérifie que le compte connecté n'est pas suspendu avant une action
/// interactive (paiement, chat, prêt, achat, enchère…).
///
/// Retourne `false` et affiche un message d'erreur si le compte est banni :
/// l'utilisateur garde l'accès en lecture à son interface, mais toutes les
/// fonctions de l'app lui sont fermées.
bool ensureNotBanned(BuildContext context, WidgetRef ref) {
  final profile = ref.read(currentProfileProvider).valueOrNull;
  if (profile != null && profile.isBanned) {
    AppFeedback.error(
      context,
      'Compte suspendu : cette action n\'est pas autorisée.',
    );
    return false;
  }
  return true;
}

/// Bandeau affiché en haut de l'accueil quand le compte est suspendu.
class BannedBanner extends ConsumerWidget {
  const BannedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (profile == null || !profile.isBanned) return const SizedBox.shrink();

    final reason = profile.banReason?.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.negative.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.negative.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.negative.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: AppTheme.negative,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compte suspendu',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.negative,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reason == null || reason.isEmpty
                      ? 'Ce compte a été suspendu par l\'administrateur. '
                          'Aucune action n\'est autorisée.'
                      : 'Motif : $reason\n'
                          'Aucune action n\'est autorisée.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.8),
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
