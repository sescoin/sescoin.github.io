import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'animations.dart';

/// Robustesse d'un mot de passe : 0 (vide) → 4 (très solide).
///
/// Partagé entre la création de compte et le changement de mot de passe pour
/// que les deux écrans notent de la même façon.
int passwordStrength(String value) {
  if (value.isEmpty) return 0;
  var score = 1;
  if (value.length >= 8) score++;
  if (value.length >= 12) score++;
  final hasLetters = value.contains(RegExp(r'[a-zA-Z]'));
  final hasDigits = value.contains(RegExp(r'[0-9]'));
  final hasSpecial = value.contains(RegExp(r'[^a-zA-Z0-9]'));
  if (hasLetters && hasDigits) score++;
  if (hasSpecial) score++;
  return score.clamp(0, 4);
}

/// Barre de robustesse animée, accompagnée de son libellé.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.strength});

  /// 1 → 4.
  final int strength;

  static const _labels = ['', 'Fragile', 'Moyen', 'Solide', 'Excellent'];

  Color get _color => switch (strength) {
        1 => AppTheme.negative,
        2 => AppTheme.warning,
        3 => AppTheme.positive,
        _ => AppTheme.positive,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: strength / 4),
              duration: AppMotion.duration(const Duration(milliseconds: 350)),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: _color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: AppMotion.duration(const Duration(milliseconds: 220)),
          child: Text(
            _labels[strength],
            key: ValueKey(strength),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ),
      ],
    );
  }
}
