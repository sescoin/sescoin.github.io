import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/animations.dart';
import '../../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Moteur des démonstrations du tutoriel.
//
// Une démonstration rejoue une manipulation sur un écran factice (la
// « scène ») : un doigt se déplace, touche, saisit du texte, et la scène
// réagit. Rien n'atteint la base : la scène ne lit que son contrôleur.
// ─────────────────────────────────────────────────────────────────────────────

/// Interrompt un scénario en cours (étape changée, tutoriel fermé).
class DemoCancelled implements Exception {
  const DemoCancelled();
}

enum DemoToastKind { success, error, warning, info }

/// Message flottant d'une scène, sur le modèle d'AppFeedback.
class DemoToast {
  const DemoToast(this.kind, this.message);

  final DemoToastKind kind;
  final String message;
}

/// État d'une démonstration : valeurs lues par la scène, curseur, légende.
class DemoController extends ChangeNotifier {
  DemoController([Map<String, Object?> initial = const {}])
      : _initial = Map.unmodifiable(initial) {
    _values.addAll(_initial);
  }

  final Map<String, Object?> _initial;
  final Map<String, Object?> _values = {};
  final Map<String, GlobalKey> _anchors = {};
  final Map<String, ScrollController> _scrollers = {};
  bool _disposed = false;

  // ── Doigt (coordonnées du plateau) ──────────────────────────────────────
  Offset cursor = Offset.zero;
  Duration cursorDuration = Duration.zero;
  bool cursorVisible = false;
  bool pressed = false;
  bool holding = false;

  /// Incrémenté à chaque toucher : déclenche l'onde.
  int tapCount = 0;
  Offset tapPosition = Offset.zero;

  // ── Retour visuel ───────────────────────────────────────────────────────
  /// Action en cours, affichée au-dessus du plateau.
  String? caption;
  int captionNumber = 0;
  DemoToast? toast;

  /// Zone de l'élément mis en avant, mesurée par le halo du plateau. Sert à
  /// orienter la pointe de la bulle explicative.
  final focusRect = ValueNotifier<Rect?>(null);

  T? get<T>(String key) => _values[key] as T?;

  String text(String key) => _values[key] as String? ?? '';

  bool flag(String key) => _values[key] == true;

  double number(String key, [double fallback = 0]) =>
      (_values[key] as num?)?.toDouble() ?? fallback;

  /// Page affichée par une scène à plusieurs écrans.
  String get page => _values['page'] as String? ?? '';

  void set(String key, Object? value) {
    _values[key] = value;
    notify();
  }

  void notify() {
    if (!_disposed) notifyListeners();
  }

  /// Clé posée sur un élément que le doigt peut viser.
  GlobalKey anchor(String id) =>
      _anchors.putIfAbsent(id, () => GlobalKey(debugLabel: 'demo:$id'));

  /// Repère [child] comme cible du doigt sous le nom [id].
  Widget mark(String id, Widget child) =>
      _DemoMark(anchor: anchor(id), child: child);

  ScrollController scroller(String id) =>
      _scrollers.putIfAbsent(id, ScrollController.new);

  /// Remet la scène dans son état de départ, avant de rejouer l'exemple.
  void reset() {
    _values
      ..clear()
      ..addAll(_initial);
    cursorVisible = false;
    pressed = false;
    holding = false;
    caption = null;
    captionNumber = 0;
    toast = null;
    for (final scroller in _scrollers.values) {
      if (scroller.hasClients) scroller.jumpTo(0);
    }
    notify();
  }

  @override
  void dispose() {
    _disposed = true;
    focusRect.dispose();
    for (final scroller in _scrollers.values) {
      scroller.dispose();
    }
    super.dispose();
  }
}

/// Repère posé par [DemoController.mark].
///
/// Pendant une transition, l'écran sortant et l'écran entrant portent les
/// mêmes repères : le sortant y renonce, sans quoi la même clé figurerait
/// deux fois dans l'arbre.
class _DemoMark extends StatelessWidget {
  const _DemoMark({required this.anchor, required this.child});

  final GlobalKey anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => _DemoLeaving.of(context)
      ? child
      : KeyedSubtree(key: anchor, child: child);
}

/// Signale aux repères qu'ils appartiennent à un écran en train de partir.
class _DemoLeaving extends InheritedWidget {
  const _DemoLeaving({
    super.key,
    required this.leaving,
    required super.child,
  });

  final bool leaving;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DemoLeaving>()?.leaving ??
      false;

  @override
  bool updateShouldNotify(_DemoLeaving oldWidget) =>
      oldWidget.leaving != leaving;
}

/// Mise en page d'un AnimatedSwitcher dont les enfants sortants renoncent
/// à leurs repères.
AnimatedSwitcherLayoutBuilder _demoSwitcherLayout(
  BuildContext context, {
  AlignmentGeometry alignment = Alignment.center,
  StackFit fit = StackFit.loose,
}) {
  final outer = _DemoLeaving.of(context);
  return (current, previous) => Stack(
        alignment: alignment,
        fit: fit,
        children: [
          for (final child in previous)
            _DemoLeaving(key: child.key, leaving: true, child: child),
          if (current != null)
            _DemoLeaving(key: current.key, leaving: outer, child: current),
        ],
      );
}

/// Position de l'élément [anchor] dans le repère du plateau [stageKey].
Rect? demoRectOf(GlobalKey stageKey, GlobalKey anchor) {
  final target = anchor.currentContext?.findRenderObject();
  final stage = stageKey.currentContext?.findRenderObject();
  if (target is! RenderBox || stage is! RenderBox) return null;
  if (!target.attached || !target.hasSize || !stage.attached) return null;
  final topLeft = target.localToGlobal(Offset.zero, ancestor: stage);
  return topLeft & target.size;
}

/// Joue le scénario d'une étape.
///
/// Chaque action vérifie qu'on ne l'a pas interrompue : un scénario arrêté
/// lève [DemoCancelled] au lieu de continuer à modifier un écran disparu.
class DemoPlayer {
  DemoPlayer(this.c, this._stageKey);

  final DemoController c;
  final GlobalKey _stageKey;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  void _check() {
    if (_cancelled) throw const DemoCancelled();
  }

  Future<void> wait(int ms) async {
    _check();
    await Future<void>.delayed(Duration(milliseconds: ms));
    _check();
  }

  void set(String key, Object? value) {
    _check();
    c.set(key, value);
  }

  /// Annonce l'action suivante (légende numérotée au-dessus du plateau).
  void say(String text) {
    _check();
    c.captionNumber++;
    c.caption = text;
    c.notify();
  }

  Rect? rectOf(String id) => demoRectOf(_stageKey, c.anchor(id));

  /// Taille du plateau, pour viser une zone sans élément repéré.
  Size get stageSize {
    final box = _stageKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : Size.zero;
  }

  /// Amène le doigt sur l'élément [id].
  Future<void> moveTo(
    String id, {
    Alignment at = Alignment.center,
    int ms = 650,
  }) async {
    // Laisse la scène se mettre en page après le dernier changement.
    await wait(40);
    final rect = rectOf(id);
    if (rect == null) return;
    await moveToPoint(at.withinRect(rect), ms: ms);
  }

  Future<void> moveToPoint(Offset target, {int ms = 650}) async {
    if (!c.cursorVisible) {
      // Première apparition : le doigt entre par le bas, près de la cible.
      c
        ..cursorDuration = Duration.zero
        ..cursor = target + const Offset(36, 80)
        ..cursorVisible = true;
      c.notify();
      await wait(50);
    }
    c
      ..cursorDuration = Duration(milliseconds: ms)
      ..cursor = target;
    c.notify();
    await wait(ms + 80);
  }

  void _release() {
    c
      ..pressed = false
      ..holding = false
      ..tapCount += 1
      ..tapPosition = c.cursor;
    c.notify();
  }

  /// Touche l'élément [id].
  Future<void> tap(String id, {Alignment at = Alignment.center}) async {
    await moveTo(id, at: at);
    c.pressed = true;
    c.notify();
    await wait(140);
    _release();
    await wait(280);
  }

  /// Touche un point précis du plateau (colonne d'un graphique…).
  Future<void> tapAt(Offset point) async {
    await moveToPoint(point);
    c.pressed = true;
    c.notify();
    await wait(140);
    _release();
    await wait(280);
  }

  /// Appui long sur l'élément [id] (anneau de progression autour du doigt).
  Future<void> longPress(String id, {Alignment at = Alignment.center}) async {
    await moveTo(id, at: at);
    await _hold();
  }

  Future<void> longPressAt(Offset point) async {
    await moveToPoint(point);
    await _hold();
  }

  Future<void> _hold() async {
    c
      ..pressed = true
      ..holding = true;
    c.notify();
    await wait(850);
    _release();
    await wait(280);
  }

  /// Saisit [text] lettre par lettre dans le champ [key], à la suite du
  /// texte déjà présent si [append].
  Future<void> type(
    String key,
    String text, {
    int perChar = 55,
    bool append = false,
  }) async {
    final start = append ? c.text(key) : '';
    for (var i = 1; i <= text.length; i++) {
      set(key, start + text.substring(0, i));
      await wait(perChar);
    }
  }

  /// Fait défiler la scène pour amener l'élément [id] à l'écran.
  Future<void> reveal(String id, {double alignment = 0.5, int ms = 750}) async {
    await wait(40);
    var context = c.anchor(id).currentContext;
    // Bas d'une longue liste : l'élément n'est construit qu'une fois proche
    // de l'écran. On descend jusqu'à le voir apparaître.
    if (context == null) {
      for (final scroller in c._scrollers.values) {
        if (scroller.positions.length != 1) continue;
        while (context == null) {
          final position = scroller.position;
          if (position.pixels >= position.maxScrollExtent) break;
          await scroller.animateTo(
            math.min(
              position.pixels + position.viewportDimension * 0.6,
              position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
          );
          _check();
          context = c.anchor(id).currentContext;
        }
        if (context != null) break;
      }
    }
    if (context == null || !context.mounted) return;
    await Scrollable.ensureVisible(
      context,
      alignment: alignment,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOutCubic,
    );
    await wait(120);
  }

  /// Glisse le doigt d'un point à l'autre, appui maintenu.
  Future<void> drag(
    List<Offset> points, {
    int stepMs = 120,
    void Function(int index)? onPoint,
  }) async {
    if (points.isEmpty) return;
    await moveToPoint(points.first, ms: 550);
    c.pressed = true;
    c.notify();
    onPoint?.call(0);
    await wait(90);
    for (var i = 1; i < points.length; i++) {
      c
        ..cursorDuration = Duration(milliseconds: stepMs)
        ..cursor = points[i];
      c.notify();
      await wait(stepMs);
      onPoint?.call(i);
    }
    await wait(120);
    c.pressed = false;
    c.notify();
    await wait(240);
  }

  /// Affiche un message de confirmation, comme l'application.
  Future<void> toast(
    String message, {
    DemoToastKind kind = DemoToastKind.success,
    int ms = 2200,
  }) async {
    _check();
    c.toast = DemoToast(kind, message);
    c.notify();
    await wait(ms);
    c.toast = null;
    c.notify();
  }

  void hideCursor() {
    c.cursorVisible = false;
    c.notify();
  }
}

/// Plateau : la scène factice, et par-dessus le halo de mise en avant, les
/// messages, l'onde de toucher et le doigt.
class DemoStage extends StatelessWidget {
  const DemoStage({
    super.key,
    required this.controller,
    required this.stageKey,
    required this.scene,
    this.focus,
    this.showFocus = true,
  });

  final DemoController controller;
  final GlobalKey stageKey;
  final Widget scene;

  /// Élément mis en avant quand l'exemple ne joue pas.
  final String? focus;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: stageKey,
      fit: StackFit.expand,
      children: [
        // Aucune interaction : la scène n'est qu'une image animée.
        IgnorePointer(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: scene,
          ),
        ),
        if (focus != null)
          _Spotlight(
            controller: controller,
            stageKey: stageKey,
            anchorId: focus!,
            visible: showFocus,
          ),
        _ToastLayer(controller: controller),
        _RippleLayer(controller: controller),
        _CursorLayer(controller: controller),
      ],
    );
  }
}

// ── Halo de mise en avant ────────────────────────────────────────────────────

class _Spotlight extends StatefulWidget {
  const _Spotlight({
    required this.controller,
    required this.stageKey,
    required this.anchorId,
    required this.visible,
  });

  final DemoController controller;
  final GlobalKey stageKey;
  final String anchorId;
  final bool visible;

  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Rect? _rect;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!AppMotion.reduce) _pulse.repeat(reverse: true);
    widget.controller.addListener(_scheduleMeasure);
  }

  @override
  void didUpdateWidget(covariant _Spotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleMeasure);
      widget.controller.addListener(_scheduleMeasure);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleMeasure);
    _pulse.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final rect = demoRectOf(
        widget.stageKey,
        widget.controller.anchor(widget.anchorId),
      );
      widget.controller.focusRect.value = widget.visible ? rect : null;
      if (rect != _rect) setState(() => _rect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mesure après chaque mise en page : la scène peut défiler ou changer
    // de taille sans prévenir.
    _scheduleMeasure();

    final rect = _rect;
    if (rect == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final accent = context.accent;
    return Positioned.fromRect(
      rect: rect.inflate(7),
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: widget.visible ? 1 : 0,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulse.value);
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.95 - 0.35 * t),
                    width: 2.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18 + 0.22 * t),
                      blurRadius: 10 + 10 * t,
                      spreadRadius: 1 + 2 * t,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Doigt ────────────────────────────────────────────────────────────────────

class _CursorLayer extends StatelessWidget {
  const _CursorLayer({required this.controller});

  final DemoController controller;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return AnimatedPositioned(
          duration: c.cursorDuration,
          curve: Curves.easeInOutCubic,
          left: c.cursor.dx - _size / 2,
          top: c.cursor.dy - _size / 2,
          width: _size,
          height: _size,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: c.cursorVisible ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 130),
                scale: c.pressed ? 0.78 : 1,
                child: _Finger(holding: c.holding),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Finger extends StatelessWidget {
  const _Finger({required this.holding});

  final bool holding;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.22),
          ),
        ),
        if (holding)
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 820),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                color: accent,
              ),
            ),
          ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Onde de toucher ──────────────────────────────────────────────────────────

class _RippleLayer extends StatefulWidget {
  const _RippleLayer({required this.controller});

  final DemoController controller;

  @override
  State<_RippleLayer> createState() => _RippleLayerState();
}

class _RippleLayerState extends State<_RippleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _seen = widget.controller.tapCount;
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _wave.dispose();
    super.dispose();
  }

  void _onChange() {
    if (widget.controller.tapCount != _seen) {
      _seen = widget.controller.tapCount;
      _wave.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => CustomPaint(
            painter: _RipplePainter(
              center: widget.controller.tapPosition,
              t: _wave.isAnimating ? _wave.value : 0,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.center, required this.t, required this.color});

  final Offset center;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      center,
      12 + 34 * eased,
      Paint()
        ..color = color.withValues(alpha: 0.55 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      10 + 18 * eased,
      Paint()..color = color.withValues(alpha: 0.18 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.center != center;
}

// ── Messages ─────────────────────────────────────────────────────────────────

class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final toast = controller.toast;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: toast == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : DemoToastCard(key: ValueKey(toast), toast: toast),
            );
          },
        ),
      ),
    );
  }
}

/// Message flottant, à l'identique des messages d'AppFeedback.
class DemoToastCard extends StatelessWidget {
  const DemoToastCard({super.key, required this.toast});

  final DemoToast toast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, color) = switch (toast.kind) {
      DemoToastKind.success => (Icons.check_circle_rounded, AppTheme.positive),
      DemoToastKind.error => (Icons.error_rounded, AppTheme.negative),
      DemoToastKind.warning => (Icons.warning_rounded, AppTheme.warning),
      DemoToastKind.info => (Icons.info_rounded, AppTheme.info),
    };
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2136) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              toast.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.close_rounded,
            size: 18,
            color: textColor.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

/// Fenêtre d'un écran factice (dialogue centré ou feuille du bas), avec son
/// voile sombre.
class DemoModal extends StatelessWidget {
  const DemoModal({
    super.key,
    required this.open,
    required this.child,
    this.sheet = false,
  });

  final bool open;
  final Widget child;

  /// Feuille ancrée en bas plutôt que dialogue centré.
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: open ? 1 : 0,
            child: const ColoredBox(color: Color(0x8A000000)),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: _demoSwitcherLayout(context),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: sheet
                  ? SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.22),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    )
                  : ScaleTransition(
                      scale:
                          Tween<double>(begin: 0.92, end: 1).animate(animation),
                      child: child,
                    ),
            ),
            child: open
                ? KeyedSubtree(
                    key: const ValueKey('open'),
                    child: sheet
                        ? Align(alignment: Alignment.bottomCenter, child: child)
                        : child,
                  )
                : const SizedBox.shrink(key: ValueKey('closed')),
          ),
        ],
      ),
    );
  }
}

/// Écrans successifs d'une scène, avec la transition d'une page poussée.
class DemoPages extends StatelessWidget {
  const DemoPages({super.key, required this.page, required this.builder});

  final String page;
  final Widget Function(String page) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: _demoSwitcherLayout(context, fit: StackFit.expand),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.10, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(page), child: builder(page)),
    );
  }
}

/// Montant qui glisse vers sa nouvelle valeur (solde crédité, débité…).
class DemoAmount extends StatelessWidget {
  const DemoAmount({
    super.key,
    required this.value,
    required this.style,
    this.suffix = ' SC',
  });

  final double value;
  final TextStyle? style;
  final String suffix;

  /// « 1 250.00 », comme la carte de solde de l'accueil.
  static String format(double value) =>
      value.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]} ',
          );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${format(v)}$suffix', style: style),
    );
  }
}

/// Point d'insertion clignotant d'un champ factice.
class DemoCaret extends StatefulWidget {
  const DemoCaret({super.key});

  @override
  State<DemoCaret> createState() => _DemoCaretState();
}

class _DemoCaretState extends State<DemoCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (!AppMotion.reduce) _blink.repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(
        width: 2,
        height: 18,
        margin: const EdgeInsets.only(left: 1),
        color: context.accent,
      ),
    );
  }
}

/// Points répartis sur [rect], pour un glisser de doigt : une valeur entre 0
/// (bas) et 1 (haut) par colonne.
List<Offset> demoColumnPath(Rect rect, List<double> heights) {
  final count = heights.length;
  return [
    for (var i = 0; i < count; i++)
      Offset(
        rect.left + rect.width * (i + 0.5) / count,
        rect.top + rect.height * (1 - heights[i].clamp(0.0, 1.0)),
      ),
  ];
}

/// Arrondit vers le haut à une graduation « ronde » (1, 2, 5 × 10ⁿ).
double demoNiceCeil(double value, {double minimum = 10}) {
  if (value <= minimum) return minimum;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor());
  for (final factor in [1, 2, 5, 10]) {
    final candidate = magnitude * factor;
    if (candidate >= value) return candidate.toDouble();
  }
  return (magnitude * 10).toDouble();
}
