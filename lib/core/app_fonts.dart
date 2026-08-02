import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Police de caractères de l'application, choisie dans les réglages.
///
/// Les familles retenues sont volontairement éloignées les unes des autres —
/// humaniste, géométrique élancée, grotesque, technique, display, monospace —
/// pour que le changement se voie immédiatement.
///
/// Si une clé enregistrée ne correspond plus à aucune entrée (famille retirée
/// d'une version à l'autre), [fontByKey] retombe sur la police système.
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
  AppFont(key: 'ubuntu', label: 'Ubuntu', family: 'Ubuntu'),
  AppFont(key: 'josefinSans', label: 'Josefin Sans', family: 'Josefin Sans'),
  AppFont(key: 'spaceGrotesk', label: 'Space Grotesk', family: 'Space Grotesk'),
  AppFont(key: 'orbitron', label: 'Orbitron', family: 'Orbitron'),
  AppFont(key: 'righteous', label: 'Righteous', family: 'Righteous'),
  AppFont(
    key: 'jetBrainsMono',
    label: 'JetBrains Mono',
    family: 'JetBrains Mono',
  ),
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
