import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';

/// Écran de personnalisation de l'esthétique de l'application.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Réinitialiser ?'),
                  content: const Text(
                    'Tous les réglages d\'apparence reviendront à leurs valeurs par défaut.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                notifier.reset();
                if (context.mounted) {
                  AppFeedback.success(context, 'Réglages réinitialisés');
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn.staggered(
            index: 0,
            child: _SectionTitle(
              icon: Icons.brightness_6_rounded,
              title: 'Thème',
            ),
          ),
          FadeSlideIn.staggered(
            index: 1,
            child: Row(
              children: [
                _ThemeModeCard(
                  label: 'Système',
                  icon: Icons.phone_android_rounded,
                  selected: settings.themeMode == ThemeMode.system,
                  onTap: () => notifier.setThemeMode(ThemeMode.system),
                ),
                const SizedBox(width: 10),
                _ThemeModeCard(
                  label: 'Clair',
                  icon: Icons.light_mode_rounded,
                  selected: settings.themeMode == ThemeMode.light,
                  onTap: () => notifier.setThemeMode(ThemeMode.light),
                ),
                const SizedBox(width: 10),
                _ThemeModeCard(
                  label: 'Sombre',
                  icon: Icons.dark_mode_rounded,
                  selected: settings.themeMode == ThemeMode.dark,
                  onTap: () => notifier.setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn.staggered(
            index: 2,
            child: _SettingsCard(
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                secondary: const Icon(Icons.contrast_rounded),
                title: const Text(
                  'Noir pur (OLED)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Fond entièrement noir en mode sombre',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: settings.pureBlack,
                onChanged: (v) => notifier.setPureBlack(v),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn.staggered(
            index: 3,
            child: _SectionTitle(
              icon: Icons.palette_rounded,
              title: 'Couleur d\'accent',
              trailing: settings.accent.label,
            ),
          ),
          FadeSlideIn.staggered(
            index: 4,
            child: _SettingsCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final accent in appAccents)
                      _AccentDot(
                        accent: accent,
                        selected: settings.accentKey == accent.key,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setAccent(accent.key);
                        },
                      ),
                    _CustomAccentDot(
                      selected: settings.accentKey == customAccentKey,
                      currentColor: settings.customAccent,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final picked = await showDialog<Color>(
                          context: context,
                          builder: (_) => _ColorPickerDialog(
                            initialColor: settings.customAccent ??
                                settings.accent.color,
                          ),
                        );
                        if (picked != null) {
                          notifier.setCustomAccent(picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn.staggered(
            index: 5,
            child: _SectionTitle(
              icon: Icons.accessibility_new_rounded,
              title: 'Confort',
            ),
          ),
          FadeSlideIn.staggered(
            index: 6,
            child: _SettingsCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    secondary: const Icon(Icons.animation_rounded),
                    title: const Text(
                      'Réduire les animations',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Désactive les effets décoratifs',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.reduceMotion,
                    onChanged: (v) => notifier.setReduceMotion(v),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_size_rounded, size: 22),
                            const SizedBox(width: 14),
                            const Text(
                              'Taille du texte',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<double>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            segments: const [
                              ButtonSegment(value: 0.9, label: Text('Petit')),
                              ButtonSegment(value: 1.0, label: Text('Normal')),
                              ButtonSegment(value: 1.1, label: Text('Grand')),
                            ],
                            selected: {settings.textScale},
                            onSelectionChanged: (selection) =>
                                notifier.setTextScale(selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn.staggered(
            index: 7,
            child: _SectionTitle(
              icon: Icons.visibility_rounded,
              title: 'Aperçu',
            ),
          ),
          FadeSlideIn.staggered(index: 8, child: const _PreviewCard()),
        ],
      ),
    );
  }
}

// ── Titre de section ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            AnimatedSwitcher(
              duration: AppMotion.duration(const Duration(milliseconds: 220)),
              child: Text(
                trailing!,
                key: ValueKey(trailing),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carte conteneur ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: child);
  }
}

// ── Sélecteur de mode de thème ─────────────────────────────────────────────────

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(const Duration(milliseconds: 240)),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.13)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary
                  : theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected
                    ? primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pastille d'accent ──────────────────────────────────────────────────────────

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Accent ${accent.label}',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.duration(const Duration(milliseconds: 240)),
              curve: Curves.easeOutBack,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent.color, accent.dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.color.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration:
                    AppMotion.duration(const Duration(milliseconds: 200)),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        color: AppTheme.onAccent(accent.color),
                        size: 22,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              accent.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pastille multicolore (couleur libre) ───────────────────────────────────────

class _CustomAccentDot extends StatelessWidget {
  const _CustomAccentDot({
    required this.selected,
    required this.currentColor,
    required this.onTap,
  });

  final bool selected;
  final Color? currentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Couleur personnalisée',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.duration(const Duration(milliseconds: 240)),
              curve: Curves.easeOutBack,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFE53935),
                    Color(0xFFFF9800),
                    Color(0xFFFFEB3B),
                    Color(0xFF4CAF50),
                    Color(0xFF03A9F4),
                    Color(0xFF3F51B5),
                    Color(0xFF9C27B0),
                    Color(0xFFE53935),
                  ],
                ),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.4,
                ),
                boxShadow: selected && currentColor != null
                    ? [
                        BoxShadow(
                          color: currentColor!.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              // Cœur : la couleur choisie (ou icône pipette si jamais choisie)
              child: Center(
                child: selected && currentColor != null
                    ? Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: currentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: AppTheme.onAccent(currentColor!),
                        ),
                      )
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.colorize_rounded,
                          size: 15,
                          color: Colors.black87,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Perso',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de couleur (HSV) ─────────────────────────────────────────────────

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    // Une couleur trop sombre/délavée donne des boutons illisibles :
    // on repart d'une base vive si nécessaire.
    if (_hsv.saturation < 0.05 && _hsv.value < 0.05) {
      _hsv = const HSVColor.fromAHSV(1, 210, 0.8, 0.9);
    }
  }

  Color get _color => _hsv.toColor();

  String get _hex =>
      '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Couleur personnalisée'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nuance (saturation / luminosité)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.55,
                child: _SaturationValueBox(
                  hsv: _hsv,
                  onChanged: (hsv) => setState(() => _hsv = hsv),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Teinte
            _HueSlider(
              hue: _hsv.hue,
              onChanged: (hue) => setState(() => _hsv = _hsv.withHue(hue)),
            ),
            const SizedBox(height: 16),
            // Aperçu
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    size: 18,
                    color: AppTheme.onAccent(_color),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hex,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Ta couleur d\'accent',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Mini aperçu bouton
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onAccent(_color),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: AppTheme.onAccent(_color),
          ),
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Choisir'),
        ),
      ],
    );
  }
}

// ── Carré saturation / luminosité ──────────────────────────────────────────────

class _SaturationValueBox extends StatelessWidget {
  const _SaturationValueBox({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _handle(Offset localPosition, Size size) {
    final s = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SvPainter(hsv: hsv),
          ),
        );
      },
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter({required this.hsv});

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();

    // Blanc → teinte pure (horizontal)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    // Transparent → noir (vertical)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    // Curseur
    final pos = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      pos,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      pos,
      9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}

// ── Barre de teinte ────────────────────────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  void _handle(Offset localPosition, double width) {
    final h = (localPosition.dx / width).clamp(0.0, 1.0) * 360.0;
    onChanged(h.clamp(0.0, 359.9));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handle(d.localPosition, width),
            onPanUpdate: (d) => _handle(d.localPosition, width),
            child: CustomPaint(
              size: Size(width, 26),
              painter: _HuePainter(hue: hue),
            ),
          );
        },
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 7, size.width, 14),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var h = 0; h <= 360; h += 30)
              HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
          ],
        ).createShader(track.outerRect),
    );

    final x = (hue / 360.0) * size.width;
    final center = Offset(x.clamp(9, size.width - 9), size.height / 2);
    canvas.drawCircle(
      center,
      10,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _HuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}

// ── Aperçu en direct ───────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini carte de solde
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1A2E),
                    Color.lerp(const Color(0xFF16213E), primary, 0.14)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mon solde',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '128,50 SC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@prenom.nom',
                    style: TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Bulle de chat + bouton
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A3E)
                          : const Color(0xFFEFEDE6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(5),
                      ),
                    ),
                    child: Text(
                      'Salut ! Voici l\'aperçu 👋',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(5),
                      ),
                    ),
                    child: Text(
                      'Superbe couleur !',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onAccent(primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Bouton'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Contour'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
