import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_dialog.dart';
import 'dispose_scope.dart';

/// Suspension demandée par l'administrateur.
class BanRequest {
  const BanRequest({this.reason, this.minutes});

  final String? reason;

  /// Durée en minutes. `null` vaut suspension sans terme.
  final int? minutes;
}

/// Durées proposées. Le libellé sert aussi au récapitulatif.
const _durations = <(String, int?)>[
  ('1 heure', 60),
  ('24 heures', 1440),
  ('7 jours', 10080),
  ('Sans terme', null),
];

/// Demande motif et durée avant de suspendre un compte.
///
/// Renvoie `null` si l'administrateur renonce.
Future<BanRequest?> showBanDialog(
  BuildContext context,
  String username, {
  String initialReason = '',
}) {
  final reasonCtrl = TextEditingController(text: initialReason);
  // Par défaut 24 h : une sanction courte se révise plus facilement qu'un
  // bannissement définitif posé dans l'urgence.
  var selected = 1440;

  return showDialog<BanRequest>(
    context: context,
    builder: (ctx) => DisposeScope(
      disposables: [reasonCtrl],
      child: StatefulBuilder(
        builder: (ctx, setLocal) => AppDialog(
          icon: Icons.gavel_rounded,
          tone: AppDialogTone.danger,
          title: 'Suspendre @$username',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Motif'),
              ),
              const SizedBox(height: 16),
              Text(
                'Durée',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final (label, minutes) in _durations)
                    _DurationChip(
                      label: label,
                      selected: selected == minutes,
                      onTap: () => setLocal(() => selected = minutes ?? -1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                selected == -1
                    ? 'Le compte restera suspendu jusqu\'à une levée manuelle.'
                    : 'La suspension sera levée automatiquement.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.negative,
              ),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                Navigator.pop(
                  ctx,
                  BanRequest(
                    reason: reason.isEmpty ? null : reason,
                    minutes: selected == -1 ? null : selected,
                  ),
                );
              },
              child: const Text('Suspendre'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? accent : null,
          ),
        ),
      ),
    );
  }
}
