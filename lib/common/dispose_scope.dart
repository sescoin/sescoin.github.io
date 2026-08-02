import 'package:flutter/material.dart';

/// Libère des objets (`TextEditingController`, `FocusNode`…) au moment où le
/// widget quitte réellement l'arbre, et non dès que `showDialog()` retourne.
///
/// ## Le problème résolu
///
/// Le motif suivant est piégeux :
///
/// ```dart
/// final ctrl = TextEditingController();
/// final ok = await showDialog<bool>(...TextField(controller: ctrl)...);
/// final texte = ctrl.text;
/// ctrl.dispose();            // ← trop tôt
/// ```
///
/// `showDialog()` se termine dès l'appel à `Navigator.pop()`, mais la route
/// reste montée pendant toute son animation de fermeture (~200 ms) et le
/// `TextField` continue d'être reconstruit. Le controller étant déjà détruit,
/// Flutter lève « A TextEditingController was used after being disposed »
/// pendant un `build`, ce qui déclenche `ErrorWidget.builder`.
///
/// Symptôme observé : le dialog se ferme, l'action est bien effectuée côté
/// serveur, mais l'écran affiche une erreur — aussi bien sur « Annuler » que
/// sur « Enregistrer », puisque le `dispose()` a lieu dans les deux cas.
///
/// ## Usage
///
/// ```dart
/// final ctrl = TextEditingController();
/// final ok = await showDialog<bool>(
///   context: context,
///   builder: (ctx) => DisposeScope(
///     disposables: [ctrl],
///     child: AlertDialog(...),
///   ),
/// );
/// final texte = ctrl.text;   // sûr : le pop précède le démontage
/// ```
///
/// Lire la valeur après le `await` reste valide : `showDialog()` reprend la
/// main avant que l'animation de fermeture ne soit terminée, donc avant le
/// `dispose()`.
class DisposeScope extends StatefulWidget {
  const DisposeScope({
    super.key,
    required this.disposables,
    required this.child,
  });

  /// Objets à libérer une fois le dialog démonté.
  final List<ChangeNotifier> disposables;

  final Widget child;

  @override
  State<DisposeScope> createState() => _DisposeScopeState();
}

class _DisposeScopeState extends State<DisposeScope> {
  @override
  void dispose() {
    for (final disposable in widget.disposables) {
      disposable.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
