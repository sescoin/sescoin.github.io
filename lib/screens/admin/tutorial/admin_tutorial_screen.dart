import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/user_handle.dart';
import '../../../providers/auth_provider.dart';
import 'tutorial_engine.dart';
import 'tutorial_mock.dart';
import 'tutorial_steps.dart';

/// Tutoriel de l'administrateur : chaque étape présente une fonction sur un
/// écran factice, avec une bulle explicative et un exemple joué à la demande.
class AdminTutorialScreen extends ConsumerStatefulWidget {
  const AdminTutorialScreen({super.key});

  @override
  ConsumerState<AdminTutorialScreen> createState() =>
      _AdminTutorialScreenState();
}

/// Scène d'une étape : son contrôleur et la clé de son plateau.
class _StepSession {
  _StepSession(this.step) : controller = DemoController(step.initial);

  final TutorialStep step;
  final DemoController controller;
  final GlobalKey stageKey = GlobalKey();
}

/// Porte la scène d'une étape et libère son contrôleur quand elle quitte
/// l'arbre, une fois le fondu vers l'étape suivante terminé.
class _SessionHost extends StatefulWidget {
  const _SessionHost({super.key, required this.session, required this.child});

  final _StepSession session;
  final Widget child;

  @override
  State<_SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<_SessionHost> {
  @override
  void dispose() {
    widget.session.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AdminTutorialScreenState extends ConsumerState<AdminTutorialScreen> {
  int _index = 0;
  late _StepSession _session = _StepSession(tutorialSteps.first);
  DemoPlayer? _player;
  bool _collapsed = false;
  final Set<int> _played = {};

  bool get _playing => _player != null;
  bool get _paused => _player?.paused ?? false;
  bool get _isLast => _index == tutorialSteps.length - 1;

  // Le contrôleur d'une étape est libéré par [_SessionHost], quand sa scène
  // quitte l'arbre.
  @override
  void dispose() {
    _player?.cancel();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goTo(int index) {
    if (index < 0 || index >= tutorialSteps.length || index == _index) return;
    _player?.cancel();
    setState(() {
      _player = null;
      _index = index;
      _collapsed = false;
      _session = _StepSession(tutorialSteps[index]);
    });
  }

  void _next() {
    if (_isLast) {
      _quit();
    } else {
      _goTo(_index + 1);
    }
  }

  void _previous() => _goTo(_index - 1);

  void _quit() => Navigator.of(context).maybePop();

  // ── Exemple ───────────────────────────────────────────────────────────────

  Future<void> _play() async {
    final script = _session.step.script;
    if (script == null) return;
    _player?.cancel();
    final session = _session;
    final index = _index;
    session.controller.reset();
    final player = DemoPlayer(session.controller, session.stageKey);
    setState(() => _player = player);

    try {
      // Laisse la bulle s'effacer avant le premier geste.
      await player.wait(450);
      await script(player);
      await player.wait(1200);
    } on DemoCancelled {
      return;
    }

    if (!mounted || _player != player) return;
    session.controller.reset();
    setState(() {
      _player = null;
      _played.add(index);
    });
  }

  void _stop() {
    final player = _player;
    if (player == null) return;
    player.cancel();
    _session.controller.reset();
    setState(() => _player = null);
  }

  void _togglePause() {
    final player = _player;
    if (player == null) return;
    setState(() => player.paused ? player.resume() : player.pause());
  }

  // ── Sommaire ──────────────────────────────────────────────────────────────

  void _openSummary() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        builder: (context, scroll) => _Summary(
          scroll: scroll,
          current: _index,
          played: _played,
          onSelect: (i) {
            Navigator.of(sheetContext).pop();
            _goTo(i);
          },
        ),
      ),
    );
  }

  // ── Écran ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final step = _session.step;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _playing ? _togglePause() : _play(),
        const SingleActivator(LogicalKeyboardKey.escape): _stop,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  index: _index,
                  step: step,
                  controller: _session.controller,
                  playing: _playing,
                  paused: _paused,
                  onQuit: _quit,
                  onSummary: _openSummary,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 440,
                          maxHeight: 920,
                        ),
                        child: _StageFrame(
                          child: _PhoneScale(
                            child: ProviderScope(
                              // Les tuiles de transaction se lisent par rapport
                              // au compte fictif de la démonstration.
                              overrides: [
                                currentUserIdProvider
                                    .overrideWithValue(demoMeId),
                              ],
                              child: DemoIdentity(
                                // Le tutoriel est réservé à l'administrateur :
                                // ses écrans portent son nom public.
                                name: adminPublicName,
                                username: profile?.username ?? adminUsername,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  child: _SessionHost(
                                    key: ObjectKey(_session),
                                    session: _session,
                                    child: _StepView(
                                      session: _session,
                                      playing: _playing,
                                      played: _played.contains(_index),
                                      collapsed: _collapsed,
                                      onPlay: _play,
                                      onToggle: () => setState(
                                          () => _collapsed = !_collapsed),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _BottomBar(
                  index: _index,
                  playing: _playing,
                  paused: _paused,
                  isLast: _isLast,
                  onPrevious: _index > 0 ? _previous : null,
                  onNext: _next,
                  onStop: _stop,
                  onTogglePause: _togglePause,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── En-tête : quitter, progression ou légende de l'exemple ───────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.index,
    required this.step,
    required this.controller,
    required this.playing,
    required this.paused,
    required this.onQuit,
    required this.onSummary,
  });

  final int index;
  final TutorialStep step;
  final DemoController controller;
  final bool playing;
  final bool paused;
  final VoidCallback onQuit;
  final VoidCallback onSummary;

  static final _compact = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final total = tutorialSteps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Flexible(
                  child: TextButton.icon(
                    onPressed: onQuit,
                    style: _compact,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Quitter le tutoriel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onSummary,
                  style: _compact,
                  icon: const Icon(Icons.menu_rounded),
                  label: const Text('Sommaire'),
                ),
              ],
            ),
          ),
          // Hauteur fixe : le plateau ne doit pas bouger pendant l'exemple.
          SizedBox(
            height: 46,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: playing
                  ? _Caption(
                      key: const ValueKey('caption'),
                      controller: controller,
                      paused: paused,
                    )
                  : Padding(
                      key: const ValueKey('progress'),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(step.chapter.icon, size: 15, color: accent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  step.chapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                              Text(
                                'Étape ${index + 1} / $total',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: (index + 1) / total),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: accent.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action en cours de l'exemple, numérotée.
class _Caption extends StatelessWidget {
  const _Caption({
    super.key,
    required this.controller,
    required this.paused,
  });

  final DemoController controller;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final caption = controller.caption;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(controller.captionNumber),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: caption == null
                      ? Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: context.onAccent,
                        )
                      : Text(
                          '${controller.captionNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.onAccent,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    caption ?? 'Démonstration…',
                    key: ValueKey(controller.captionNumber),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              if (paused) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'En pause',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Cadre du plateau ─────────────────────────────────────────────────────────

class _StageFrame extends StatelessWidget {
  const _StageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: child,
        ),
      ),
    );
  }
}

/// Les écrans factices sont dessinés pour un téléphone d'au moins
/// [_phoneWidth] de large : sur un écran plus étroit, on les met en page à
/// cette largeur puis on réduit l'ensemble, comme une miniature.
class _PhoneScale extends StatelessWidget {
  const _PhoneScale({required this.child});

  final Widget child;

  static const _phoneWidth = 390.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _phoneWidth || width <= 0) return child;
        final scale = width / _phoneWidth;
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _phoneWidth,
            height: constraints.maxHeight / scale,
            child: child,
          ),
        );
      },
    );
  }
}

// ── Étape : plateau et bulle ─────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  const _StepView({
    required this.session,
    required this.playing,
    required this.played,
    required this.collapsed,
    required this.onPlay,
    required this.onToggle,
  });

  final _StepSession session;
  final bool playing;
  final bool played;
  final bool collapsed;
  final VoidCallback onPlay;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final step = session.step;
    final c = session.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            DemoStage(
              controller: c,
              stageKey: session.stageKey,
              focus: step.focus,
              showFocus: !playing,
              scene: ListenableBuilder(
                listenable: c,
                builder: (context, _) => step.scene(context, c),
              ),
            ),
            ValueListenableBuilder<Rect?>(
              valueListenable: c.focusRect,
              builder: (context, focus, _) {
                // La bulle se place dans la moitié opposée à l'élément mis
                // en avant, pour ne pas le cacher.
                final onTop =
                    focus != null && focus.center.dy > size.height / 2;
                return AnimatedAlign(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  alignment:
                      onTop ? Alignment.topCenter : Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: playing,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: playing ? 0 : 1,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        offset: playing
                            ? Offset(0, onTop ? -0.08 : 0.08)
                            : Offset.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: size.height * 0.58,
                            ),
                            child: _Bubble(
                              step: step,
                              focus: focus,
                              stageWidth: size.width,
                              pointUp: !onTop,
                              played: played,
                              collapsed: collapsed,
                              onPlay: onPlay,
                              onToggle: onToggle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Bulle explicative, avec sa pointe tournée vers l'élément mis en avant.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.step,
    required this.focus,
    required this.stageWidth,
    required this.pointUp,
    required this.played,
    required this.collapsed,
    required this.onPlay,
    required this.onToggle,
  });

  final TutorialStep step;
  final Rect? focus;
  final double stageWidth;

  /// Pointe en haut (bulle sous l'élément) ou en bas (bulle au-dessus).
  final bool pointUp;
  final bool played;
  final bool collapsed;
  final VoidCallback onPlay;
  final VoidCallback onToggle;

  static const _margin = 10.0;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final surface = context.isDark ? const Color(0xFF1E2136) : Colors.white;
    final border = accent.withValues(alpha: 0.45);

    // Position horizontale de la pointe, dans le repère de la bulle.
    Widget? tail;
    if (focus != null && !collapsed) {
      final width = stageWidth - 2 * _margin;
      final x = (focus!.center.dx - _margin).clamp(28.0, width - 28.0);
      tail = Align(
        alignment: Alignment(width <= 0 ? 0 : (x / width) * 2 - 1, 0),
        child: CustomPaint(
          size: const Size(22, 10),
          painter: _TailPainter(
            color: surface,
            border: border,
            pointUp: pointUp,
          ),
        ),
      );
    }

    final card = Material(
      color: surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        alignment: pointUp ? Alignment.topCenter : Alignment.bottomCenter,
        child: collapsed
            ? InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        'Afficher',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      Icon(Icons.expand_less_rounded, color: accent),
                    ],
                  ),
                ),
              )
            : _BubbleBody(
                step: step,
                played: played,
                onPlay: onPlay,
                onCollapse: onToggle,
              ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pointUp && tail != null)
          Transform.translate(
            offset: const Offset(0, 1.2),
            child: tail,
          ),
        Flexible(child: card),
        if (!pointUp && tail != null)
          Transform.translate(
            offset: const Offset(0, -1.2),
            child: tail,
          ),
      ],
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.step,
    required this.played,
    required this.onPlay,
    required this.onCollapse,
  });

  final TutorialStep step;
  final bool played;
  final VoidCallback onPlay;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(step.chapter.icon, size: 13, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            step.chapter.title,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onCollapse,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Réduire la bulle',
                      icon: Icon(Icons.expand_more_rounded, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    step.text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                if (step.points.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final (i, point) in step.points.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7, right: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(top: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              point,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (step.tip != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_rounded,
                          size: 17,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.tip!,
                            style: const TextStyle(
                              fontSize: 12.8,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (step.script != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(
                played ? Icons.replay_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(played ? 'Rejouer l\'exemple' : 'Jouer l\'exemple'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter({
    required this.color,
    required this.border,
    required this.pointUp,
  });

  final Color color;
  final Color border;
  final bool pointUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointUp
        ? (Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height))
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0));
    canvas
      ..drawPath(path..close(), Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.border != border ||
      oldDelegate.pointUp != pointUp;
}

// ── Barre du bas : retour, arrêt, suivant ────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.playing,
    required this.paused,
    required this.isLast,
    required this.onPrevious,
    required this.onNext,
    required this.onStop,
    required this.onTogglePause,
  });

  final int index;
  final bool playing;
  final bool paused;
  final bool isLast;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStop;
  final VoidCallback onTogglePause;

  static const _compact = EdgeInsets.symmetric(horizontal: 12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Pendant l'exemple, la barre ne commande que l'exemple.
    final controls = Row(
      key: const ValueKey('controls'),
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTogglePause,
            style: OutlinedButton.styleFrom(padding: _compact),
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            label: Text(paused ? 'Reprendre' : 'Pause', maxLines: 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onStop,
            style: FilledButton.styleFrom(
              padding: _compact,
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Arrêter', maxLines: 1),
          ),
        ),
      ],
    );

    final navigation = Row(
      key: const ValueKey('navigation'),
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPrevious,
            style: OutlinedButton.styleFrom(padding: _compact),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Retour', maxLines: 1),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '${index + 1} / ${tutorialSteps.length}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(padding: _compact),
            icon: Icon(
              isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(isLast ? 'Terminer' : 'Suivant', maxLines: 1),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SizedBox(
        height: 48,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: playing ? controls : navigation,
        ),
      ),
    );
  }
}

// ── Sommaire ─────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({
    required this.scroll,
    required this.current,
    required this.played,
    required this.onSelect,
  });

  final ScrollController scroll;
  final int current;
  final Set<int> played;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'Sommaire',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    ];

    TutorialChapter? chapter;
    for (final (i, step) in tutorialSteps.indexed) {
      if (step.chapter != chapter) {
        chapter = step.chapter;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(chapter.icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  chapter.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final isCurrent = i == current;
      children.add(
        ListTile(
          dense: true,
          selected: isCurrent,
          selectedTileColor: accent.withValues(alpha: 0.10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            radius: 13,
            backgroundColor: isCurrent
                ? accent
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            child: played.contains(i)
                ? Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: isCurrent ? context.onAccent : AppTheme.positive,
                  )
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCurrent
                          ? context.onAccent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          title: Text(
            step.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          onTap: () => onSelect(i),
        ),
      );
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}
