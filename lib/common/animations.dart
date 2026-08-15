import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/settings_provider.dart';

export '../providers/settings_provider.dart' show AppMotion;

/// Apparition douce : fondu + léger glissement vertical.
/// Utiliser [delay] pour créer des effets de cascade dans les listes.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = const Offset(0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  /// Cascade : décale l'apparition selon l'index de l'élément.
  ///
  /// Le décalage reste volontairement court et plafonne vite. Dans une liste
  /// défilante, un élément n'est construit qu'en approchant de l'écran : un
  /// décalage long le laisserait invisible le temps que son tour vienne,
  /// d'autant plus visible que l'on fait défiler vite.
  factory FadeSlideIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration step = const Duration(milliseconds: 22),
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return FadeSlideIn(
      key: key,
      delay: step * index.clamp(0, 6),
      duration: duration,
      child: child,
    );
  }

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);

    if (AppMotion.reduce) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Réduction d'échelle au toucher — micro-interaction sur les éléments
/// cliquables (cartes, tuiles d'action…).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed && !AppMotion.reduce ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Montant animé : compte de l'ancienne valeur vers la nouvelle.
class CountUpAmount extends StatelessWidget {
  const CountUpAmount({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 750),
  });

  final double value;
  final Widget Function(BuildContext context, double animatedValue) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, animated, _) => builder(context, animated),
    );
  }
}

/// Pastille de compteur animée (badge notifications, demandes…).
class AnimatedBadge extends StatelessWidget {
  const AnimatedBadge({
    super.key,
    required this.count,
    required this.color,
    this.size = 16,
  });

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.duration(const Duration(milliseconds: 260)),
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: count <= 0
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(count),
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}
