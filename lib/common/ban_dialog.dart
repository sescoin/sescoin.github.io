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
  final daysCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();
  final minutesCtrl = TextEditingController();

  // Par défaut 24 h : une sanction courte se révise plus facilement qu'une
  // suspension définitive posée dans l'urgence.
  var selected = 1440;
  var custom = false;

  /// Durée saisie à la main, `null` si les trois champs sont vides.
  int? typedMinutes() {
    final d = int.tryParse(daysCtrl.text.trim()) ?? 0;
    final h = int.tryParse(hoursCtrl.text.trim()) ?? 0;
    final m = int.tryParse(minutesCtrl.text.trim()) ?? 0;
    final total = d * 1440 + h * 60 + m;
    return total <= 0 ? null : total;
  }

  return showDialog<BanRequest>(
    context: context,
    builder: (ctx) => DisposeScope(
      disposables: [reasonCtrl, daysCtrl, hoursCtrl, minutesCtrl],
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
                      selected: !custom && selected == (minutes ?? -1),
                      onTap: () => setLocal(() {
                        custom = false;
                        selected = minutes ?? -1;
                      }),
                    ),
                  _DurationChip(
                    label: 'Personnalisée',
                    selected: custom,
                    onTap: () => setLocal(() => custom = true),
                  ),
                ],
              ),
              if (custom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _UnitField(controller: daysCtrl, label: 'Jours'),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _UnitField(controller: hoursCtrl, label: 'Heures'),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _UnitField(controller: minutesCtrl, label: 'Min'),
                    ),
                  ],
                ),
              ],
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
                final minutes = custom
                    ? typedMinutes()
                    : (selected == -1 ? null : selected);

                // Durée personnalisée laissée vide : on ne devine pas, on
                // laisse l'administrateur la renseigner.
                if (custom && minutes == null) return;

                Navigator.pop(
                  ctx,
                  BanRequest(
                    reason: reason.isEmpty ? null : reason,
                    minutes: minutes,
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

class _UnitField extends StatelessWidget {
  const _UnitField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 12,
        ),
      ),
    );
  }
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
