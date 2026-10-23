import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../models/maintenance_status.dart';
import '../providers/auth_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/service_providers.dart';
import '../screens/maintenance/maintenance_screen.dart';
import 'animations.dart';
import 'app_dialog.dart';
import 'app_feedback.dart';

/// Applique la maintenance à toute l'application.
///
/// Posé dans `MaterialApp.builder`, au-dessus du navigateur : l'écran de
/// maintenance recouvre n'importe quelle page, dialogues compris, et
/// l'application reste montée dessous pour reprendre là où elle en était.
///
/// La structure de l'arbre ne varie jamais : seul le contenu des couches
/// change, pour que le navigateur ne soit pas reconstruit (et ses pages
/// perdues) à l'ouverture ou à la fin d'une maintenance.
class MaintenanceGate extends ConsumerWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(maintenanceProvider);
    final blocked = status.blocked;

    ref.listen(maintenanceProvider, (previous, next) {
      final signedIn =
          ref.read(supabaseClientProvider).auth.currentSession != null;
      if (signedIn && (previous?.blocked ?? false) && !next.blocked) {
        AppFeedback.success(context, 'Maintenance terminée : bon retour !');
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: blocked,
          child: ExcludeFocus(
            excluding: blocked,
            child: IgnorePointer(
              ignoring: blocked,
              child: TickerMode(
                enabled: !blocked,
                child: _OperatorFrame(status: status, child: child),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: AppMotion.duration(const Duration(milliseconds: 380)),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: blocked
              ? MaintenanceScreen(
                  key: ValueKey(status.mode),
                  mode: status.mode,
                  startedAt: status.startedAt,
                )
              : const SizedBox.shrink(key: ValueKey('open')),
        ),
      ],
    );
  }
}

/// Bandeau de la session de maintenance, au-dessus de toutes les pages.
class _OperatorFrame extends ConsumerWidget {
  const _OperatorFrame({required this.status, required this.child});

  final MaintenanceStatus status;
  final Widget child;

  Future<void> _confirmEnd(WidgetRef ref) async {
    // Le bandeau est hors du navigateur : le dialogue passe par celui du
    // routeur.
    final navigatorContext =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;

    var confirmed = true;
    if (navigatorContext != null) {
      confirmed = await showDialog<bool>(
            context: navigatorContext,
            builder: (dialogContext) => AppDialog(
              icon: Icons.construction_rounded,
              title: 'Terminer la maintenance ?',
              subtitle: 'Déconnexion du compte administrateur',
              content: const Text(
                'La maintenance prend fin à la déconnexion : tous les accès '
                'sont rétablis aussitôt.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Continuer'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Terminer'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (confirmed) {
      await ref.read(currentProfileProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = status.isMaintenanceSession && status.isActive;

    return Column(
      children: [
        if (visible)
          _OperatorBanner(
            mode: status.mode,
            onEnd: () => _confirmEnd(ref),
          ),
        Expanded(
          key: const ValueKey('app'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: visible,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _OperatorBanner extends StatelessWidget {
  const _OperatorBanner({required this.mode, required this.onEnd});

  final MaintenanceMode mode;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final global = mode == MaintenanceMode.global;
    final color = global ? AppTheme.negative : AppTheme.warning;
    final onColor = AppTheme.onAccent(color);
    final top = MediaQuery.paddingOf(context).top;

    return Material(
      color: color,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, top + 7, 8, 7),
        child: Row(
          children: [
            Icon(Icons.construction_rounded, size: 18, color: onColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    global
                        ? 'Maintenance globale en cours'
                        : 'Maintenance de l\'administration',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    global
                        ? 'L\'application est fermée à tous les autres comptes.'
                        : 'Les autres accès administrateur sont suspendus.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onColor.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onEnd,
              style: TextButton.styleFrom(
                foregroundColor: onColor,
                backgroundColor: onColor.withValues(alpha: 0.16),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
                textStyle: TextStyle(
                  fontFamily: context.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              child: const Text('Terminer'),
            ),
          ],
        ),
      ),
    );
  }
}
