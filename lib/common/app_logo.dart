import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';

/// Logo SES Coin stylisé : pièce au dégradé d'accent, anneau lumineux et
/// halo. Utilisé sur le splash, la connexion et les écrans d'accueil.
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

/// Écran de lancement animé : le logo surgit avec un rebond, le nom se
/// dévoile, puis l'ensemble s'efface pour révéler l'application.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key});

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _exitFade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: AppMotion.reduce ? 350 : 2000),
    );

    // 0 → 0.35 : le logo surgit ; 0.25 → 0.5 : le nom se dévoile ;
    // 0.8 → 1.0 : tout s'efface.
    _logoScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.35, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.18, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
      ),
    );
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.8, 1, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => IgnorePointer(
        ignoring: _exitFade.value < 0.6,
        child: Opacity(
          opacity: _exitFade.value,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const AppLogo(size: 108),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Column(
                      children: [
                        Text(
                          'SES Coin',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'La monnaie de la classe',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
