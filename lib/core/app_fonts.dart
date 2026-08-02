import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Police de caractères de l'application, choisie dans les réglages.
///
/// Les familles retenues sont volontairement éloignées les unes des autres —
/// grotesque neutre, géométrique, serif classique, slab, arrondie,
/// monospace — pour que le changement se voie immédiatement. Toutes couvrent
/// le latin étendu et restent lisibles en petit corps.
class AppFont {
  const AppFont({required this.key, required this.label, this.family});

  /// Identifiant stable pour la persistance.
  final String key;
  final String label;

  /// Nom de la famille chez Google Fonts. `null` = police du système.
  final String? family;
}

const appFonts = <AppFont>[
  AppFont(key: 'system', label: 'Système'),
  AppFont(key: 'inter', label: 'Inter', family: 'Inter'),
  AppFont(key: 'spaceGrotesk', label: 'Space Grotesk', family: 'Space Grotesk'),
  AppFont(key: 'lora', label: 'Lora', family: 'Lora'),
  AppFont(key: 'robotoSlab', label: 'Roboto Slab', family: 'Roboto Slab'),
  AppFont(key: 'quicksand', label: 'Quicksand', family: 'Quicksand'),
  AppFont(key: 'jetBrainsMono', label: 'JetBrains Mono', family: 'JetBrains Mono'),
];

AppFont fontByKey(String key) =>
    appFonts.firstWhere((f) => f.key == key, orElse: () => appFonts.first);

/// Applique la police choisie à une [TextTheme].
///
/// Les couleurs de [base] sont conservées : seule la famille change.
TextTheme applyAppFont(String key, TextTheme base) {
  final family = fontByKey(key).family;
  if (family == null) return base;
  try {
    return GoogleFonts.getTextTheme(family, base);
  } catch (_) {
    // Famille indisponible (nom modifié en amont) : on garde la police système
    // plutôt que de faire planter la construction du thème.
    return base;
  }
}

/// Nom de famille à poser sur `ThemeData.fontFamily`.
///
/// Indispensable : sans lui, les widgets qui composent leur `TextStyle` sans
/// passer par la `TextTheme` (barres de navigation, menus, info-bulles,
/// champs de saisie…) conservent la police du système, et le changement
/// n'affecte qu'une partie de l'interface.
String? appFontFamily(String key) {
  final family = fontByKey(key).family;
  if (family == null) return null;
  try {
    return GoogleFonts.getFont(family).fontFamily;
  } catch (_) {
    return null;
  }
}
