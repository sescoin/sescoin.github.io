import 'package:flutter/material.dart';

/// Logo SES Coin : le visuel est détouré au cercle et cerclé d'un fin anneau
/// dégradé repris de ses propres couleurs, pour le poser sur n'importe quel
/// fond sans qu'il paraisse flotter.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.glow = true});

  final double size;
  final bool glow;

  /// Dégradé du « S » du logo, réutilisé pour l'anneau.
  static const _ringColors = [
    Color(0xFFF7C948),
    Color(0xFFF5883C),
    Color(0xFFE1502F),
  ];

  /// Dans le fichier source (500 px), le disque noir ne mesure que 337 px, le
  /// reste étant transparent. On agrandit d'autant pour que le disque remplisse
  /// le cercle : sans cela, l'anneau cerclerait du vide.
  static const _crop = 500 / 337;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: _ringColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.34),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.07),
                ),
              ]
            : null,
      ),
      // Épaisseur de l'anneau, proportionnelle à la taille demandée.
      padding: EdgeInsets.all(size * 0.032),
      child: ClipOval(
        child: Container(
          color: const Color(0xFF0A0A0A),
          child: Transform.scale(
            scale: _crop,
            child: Image.asset(
              'assets/icons/logo.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, _, __) => Center(
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
        ),
      ),
    );
  }
}
