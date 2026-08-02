import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Police de caractères de l'application, choisie dans les réglages.
///
/// Toutes les familles proposées sont sans empattement, couvrent le latin
/// étendu (accents français compris) et disposent des graisses 400 à 800
/// utilisées par le thème — un choix volontairement sobre pour qu'aucune
/// option ne casse la mise en page.
class AppFont {
  const AppFont({
    required this.key,
    required this.label,
    required this.description,
    this.apply,
  });

  /// Identifiant stable pour la persistance.
  final String key;
  final String label;
  final String description;

  /// `null` = police système de la plateforme.
  final TextTheme Function(TextTheme base)? apply;
}

final appFonts = <AppFont>[
  const AppFont(
    key: 'system',
    label: 'Système',
    description: 'La police native de l\'appareil',
  ),
  AppFont(
    key: 'inter',
    label: 'Inter',
    description: 'Neutre et très lisible',
    apply: GoogleFonts.interTextTheme,
  ),
  AppFont(
    key: 'manrope',
    label: 'Manrope',
    description: 'Douce et arrondie',
    apply: GoogleFonts.manropeTextTheme,
  ),
  AppFont(
    key: 'outfit',
    label: 'Outfit',
    description: 'Géométrique et nette',
    apply: GoogleFonts.outfitTextTheme,
  ),
  AppFont(
    key: 'spaceGrotesk',
    label: 'Space Grotesk',
    description: 'Moderne, avec du caractère',
    apply: GoogleFonts.spaceGroteskTextTheme,
  ),
  AppFont(
    key: 'ibmPlexSans',
    label: 'IBM Plex Sans',
    description: 'Sobre et technique',
    apply: GoogleFonts.ibmPlexSansTextTheme,
  ),
  AppFont(
    key: 'nunitoSans',
    label: 'Nunito Sans',
    description: 'Chaleureuse et posée',
    apply: GoogleFonts.nunitoSansTextTheme,
  ),
];

AppFont fontByKey(String key) =>
    appFonts.firstWhere((f) => f.key == key, orElse: () => appFonts.first);

/// Applique la police choisie à une [TextTheme] de base.
///
/// Les couleurs de [base] sont conservées : `GoogleFonts` ne remplace que la
/// famille, jamais la palette calculée par le thème.
TextTheme applyAppFont(String key, TextTheme base) {
  final font = fontByKey(key);
  if (font.apply == null) return base;
  return font.apply!(base);
}
