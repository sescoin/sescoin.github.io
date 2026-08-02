import 'package:flutter/material.dart';

/// Logo SES Coin stylisé : pièce au dégradé d'accent, anneau lumineux et
/// halo. Utilisé sur la connexion et les écrans d'accueil.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    // Le logo porte déjà son propre fond : on l'affiche tel quel, détouré au
    // cercle. Pas d'anneau ni de dégradé ajouté par-dessus — seul un halo
    // d'accent reste, en arrière-plan.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: size * 0.32,
                  offset: Offset(0, size * 0.07),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icons/logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, _, __) => Container(
            color: const Color(0xFF0B0B0B),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: TextStyle(
                color: accent,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
