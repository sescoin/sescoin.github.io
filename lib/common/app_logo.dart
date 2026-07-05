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
    final dark = Color.lerp(accent, Colors.black, 0.35)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accent, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.055),
      // Anneau intérieur clair, puis la pièce elle-même.
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: size * 0.025,
          ),
        ),
        padding: EdgeInsets.all(size * 0.04),
        child: ClipOval(
          child: Image.asset(
            'assets/icons/logo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => Center(
              child: Text(
                'SC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
