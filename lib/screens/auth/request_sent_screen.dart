import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../core/router.dart';
import '../../core/theme.dart';

class RequestSentScreen extends StatelessWidget {
  const RequestSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Illustration animée ──────────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.duration(const Duration(milliseconds: 650)),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.positive.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.positive.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: AppTheme.positive,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              FadeSlideIn.staggered(
                index: 2,
                child: Text(
                  'Demande envoyée !',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn.staggered(
                index: 3,
                child: Text(
                  'Ta demande a été transmise à l\'administrateur.\n'
                  'Il va l\'examiner et créer ton compte avec '
                  'ton solde initial.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn.staggered(
                index: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tu recevras une notification dès que ton '
                          'compte est approuvé.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              FadeSlideIn.staggered(
                index: 5,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Retour à la connexion'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
