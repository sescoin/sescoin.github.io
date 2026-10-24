import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../core/theme.dart';
import '../../models/maintenance_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/maintenance_provider.dart';

/// Écran posé par-dessus l'application pendant une maintenance.
///
/// Il vit au-dessus du navigateur (voir MaintenanceGate) : ni dialogue, ni
/// info-bulle, qui exigent un Navigator ou un Overlay.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({
    super.key,
    required this.mode,
    this.startedAt,
    this.preview = false,
  });

  final MaintenanceMode mode;
  final DateTime? startedAt;

  /// Aperçu du tutoriel : boutons inertes, aucune requête.
  final bool preview;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _check() async {
    if (widget.preview || _checking) return;
    setState(() => _checking = true);
    await ref.read(maintenanceProvider.notifier).refresh();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _signOut() async {
    if (widget.preview) return;
    await ref.read(currentProfileProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    // Volontairement sobre : un titre, le médaillon et les deux boutons.
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -110,
            child: _Halo(color: accent, size: 380, strength: 0.18),
          ),
          Positioned(
            bottom: -170,
            left: -130,
            child: _Halo(color: accent, size: 420, strength: 0.09),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Maintenance',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _Emblem(accent: accent, animate: !widget.preview),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _check,
                          icon: _checking
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accent,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 19),
                          label:
                              const Text('Vérifier la fin de la maintenance'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Se déconnecter'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo(
      {required this.color, required this.size, required this.strength});

  final Color color;
  final double size;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(
                  alpha: context.isDark ? strength : strength * 0.7),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Médaillon central : outil sur fond d'accent, cerclé d'un anneau en
/// pointillés qui tourne lentement.
class _Emblem extends StatefulWidget {
  const _Emblem({required this.accent, required this.animate});

  final Color accent;
  final bool animate;

  @override
  State<_Emblem> createState() => _EmblemState();
}

class _EmblemState extends State<_Emblem> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.animate && !AppMotion.reduce) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size.square(128),
              painter: _DashedRingPainter(accent.withValues(alpha: 0.55)),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.40),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.construction_rounded,
              size: 40,
              color: AppTheme.onAccent(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashes = 18;
    const sweep = math.pi * 2 / dashes;
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
