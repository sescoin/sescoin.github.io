import 'package:flutter/material.dart';

/// Corrige le « trou blanc » laissé par le clavier sur Android quand il est
/// fermé par le geste système ou le bouton retour : Flutter garde alors le
/// focus sur le champ, et l'espace du clavier reste réservé.
///
/// Ce widget observe les métriques de la fenêtre : quand l'encart clavier
/// retombe à zéro alors qu'un champ a encore le focus, il relâche le focus,
/// ce qui rend l'espace à l'interface.
class KeyboardDismissUnfocus extends StatefulWidget {
  const KeyboardDismissUnfocus({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardDismissUnfocus> createState() => _KeyboardDismissUnfocusState();
}

class _KeyboardDismissUnfocusState extends State<KeyboardDismissUnfocus>
    with WidgetsBindingObserver {
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;

    // Le clavier vient de se fermer (l'encart passe de >0 à 0) alors qu'un
    // champ garde le focus : on le relâche pour libérer l'espace.
    if (_lastBottomInset > 0 && bottomInset <= 0) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus != null && focus.context != null) {
        focus.unfocus();
      }
    }
    _lastBottomInset = bottomInset;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
