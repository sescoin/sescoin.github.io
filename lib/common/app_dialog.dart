import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Boîte de dialogue commune à toute l'application.
///
/// Structure : un bandeau coloré (icône + titre + sous-titre), le contenu,
/// puis les actions. Passer [tone] en [AppDialogTone.danger] bascule le
/// bandeau en rouge pour les actions destructrices.
///
/// Remplace les `AlertDialog` bruts, dont l'aspect variait d'un écran à
/// l'autre.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.content,
    this.actions = const [],
    this.tone = AppDialogTone.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Corps du dialog. Reçoit déjà ses marges.
  final Widget? content;

  /// Boutons alignés à droite, dans l'ordre donné.
  final List<Widget> actions;

  final AppDialogTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = switch (tone) {
      AppDialogTone.accent => context.accent,
      AppDialogTone.danger => AppTheme.negative,
    };
    final onBase = AppTheme.onAccent(base);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Bandeau ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [base, Color.lerp(base, Colors.black, 0.26)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: onBase),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onBase,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: onBase.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Contenu ────────────────────────────────────────────────────
          if (content != null)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
                  child: content!,
                ),
              ),
            ),
          // ── Actions ────────────────────────────────────────────────────
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

enum AppDialogTone { accent, danger }
