import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instance de SharedPreferences injectée au démarrage (voir main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override dans main.dart');
});

// ── Accents disponibles ────────────────────────────────────────────────────────

class AppAccent {
  const AppAccent({
    required this.key,
    required this.label,
    required this.color,
    required this.dark,
  });

  /// Identifiant stable pour la persistance.
  final String key;
  final String label;

  /// Couleur principale (boutons, éléments actifs, montants…).
  final Color color;

  /// Variante sombre (dégradés, appuis).
  final Color dark;
}

const appAccents = <AppAccent>[
  AppAccent(
    key: 'gold',
    label: 'Or',
    color: Color(0xFFD4AF37),
    dark: Color(0xFFB8960C),
  ),
  AppAccent(
    key: 'ocean',
    label: 'Océan',
    color: Color(0xFF3B82F6),
    dark: Color(0xFF1D4ED8),
  ),
  AppAccent(
    key: 'emerald',
    label: 'Émeraude',
    color: Color(0xFF10B981),
    dark: Color(0xFF047857),
  ),
  AppAccent(
    key: 'violet',
    label: 'Violet',
    color: Color(0xFF8B5CF6),
    dark: Color(0xFF6D28D9),
  ),
  AppAccent(
    key: 'sunset',
    label: 'Corail',
    color: Color(0xFFF97316),
    dark: Color(0xFFC2410C),
  ),
  AppAccent(
    key: 'rose',
    label: 'Rose',
    color: Color(0xFFEC4899),
    dark: Color(0xFFBE185D),
  ),
  AppAccent(
    key: 'cyan',
    label: 'Lagon',
    color: Color(0xFF06B6D4),
    dark: Color(0xFF0E7490),
  ),
  AppAccent(
    key: 'crimson',
    label: 'Rubis',
    color: Color(0xFFE11D48),
    dark: Color(0xFF9F1239),
  ),
  AppAccent(
    key: 'indigo',
    label: 'Indigo',
    color: Color(0xFF6366F1),
    dark: Color(0xFF4338CA),
  ),
  AppAccent(
    key: 'slate',
    label: 'Graphite',
    color: Color(0xFF64748B),
    dark: Color(0xFF334155),
  ),
];

/// Clé réservée à la couleur choisie librement par l'utilisateur.
const customAccentKey = 'custom';

/// Construit un accent complet (couleur + variante sombre) depuis une
/// couleur arbitraire choisie au sélecteur.
AppAccent customAccentFrom(Color color) {
  final hsl = HSLColor.fromColor(color);
  final dark = hsl
      .withLightness((hsl.lightness - 0.18).clamp(0.08, 1.0))
      .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
      .toColor();
  return AppAccent(
    key: customAccentKey,
    label: 'Perso',
    color: color,
    dark: dark,
  );
}

AppAccent accentByKey(String key) =>
    appAccents.firstWhere((a) => a.key == key, orElse: () => appAccents.first);

// ── Ambiances (surfaces des thèmes clair et sombre) ────────────────────────────

/// Une ambiance définit la « matière » de l'app : couleurs de fond, de
/// cartes et de champs, pour le mode clair ET le mode sombre.
class AppAmbiance {
  const AppAmbiance({
    required this.key,
    required this.label,
    required this.icon,
    required this.lightScaffold,
    required this.lightInput,
    required this.darkScaffold,
    required this.darkSurface,
    required this.darkCard,
    required this.darkInput,
  });

  /// Identifiant stable pour la persistance.
  final String key;
  final String label;
  final IconData icon;

  final Color lightScaffold;
  final Color lightInput;
  final Color darkScaffold;
  final Color darkSurface;
  final Color darkCard;
  final Color darkInput;
}

const appAmbiances = <AppAmbiance>[
  AppAmbiance(
    key: 'classic',
    label: 'Classique',
    icon: Icons.auto_awesome_rounded,
    lightScaffold: Color(0xFFF6F4EE),
    lightInput: Color(0xFFEFEDE6),
    darkScaffold: Color(0xFF0F0F1A),
    darkSurface: Color(0xFF161829),
    darkCard: Color(0xFF1A1D31),
    darkInput: Color(0xFF23273F),
  ),
  AppAmbiance(
    key: 'frost',
    label: 'Givre',
    icon: Icons.ac_unit_rounded,
    lightScaffold: Color(0xFFF2F5F8),
    lightInput: Color(0xFFE8EDF2),
    darkScaffold: Color(0xFF0C1116),
    darkSurface: Color(0xFF121A22),
    darkCard: Color(0xFF16202A),
    darkInput: Color(0xFF1E2A36),
  ),
  AppAmbiance(
    key: 'lavender',
    label: 'Lavande',
    icon: Icons.nightlight_round,
    lightScaffold: Color(0xFFF6F3FA),
    lightInput: Color(0xFFECE6F4),
    darkScaffold: Color(0xFF120F1D),
    darkSurface: Color(0xFF181327),
    darkCard: Color(0xFF1D1730),
    darkInput: Color(0xFF272040),
  ),
  AppAmbiance(
    key: 'forest',
    label: 'Forêt',
    icon: Icons.park_rounded,
    lightScaffold: Color(0xFFF3F6F1),
    lightInput: Color(0xFFE7EDE4),
    darkScaffold: Color(0xFF0C1310),
    darkSurface: Color(0xFF121C17),
    darkCard: Color(0xFF16221C),
    darkInput: Color(0xFF1E2E26),
  ),
];

AppAmbiance ambianceByKey(String key) => appAmbiances
    .firstWhere((a) => a.key == key, orElse: () => appAmbiances.first);

// ── État des préférences ───────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accentKey = 'gold',
    this.customAccent,
    this.ambianceKey = 'classic',
    this.pureBlack = false,
    this.reduceMotion = false,
    this.textScale = 1.0,
  });

  final ThemeMode themeMode;
  final String accentKey;

  /// Ambiance des surfaces (fonds, cartes) pour les deux modes.
  final String ambianceKey;

  /// Couleur libre choisie au sélecteur (utilisée quand
  /// [accentKey] == [customAccentKey]).
  final Color? customAccent;

  /// Fond noir pur en mode sombre (écrans OLED).
  final bool pureBlack;

  /// Désactive les animations décoratives.
  final bool reduceMotion;

  /// Multiplicateur de taille de texte (0.9 / 1.0 / 1.1).
  final double textScale;

  AppAccent get accent => accentKey == customAccentKey && customAccent != null
      ? customAccentFrom(customAccent!)
      : accentByKey(accentKey);

  AppAmbiance get ambiance => ambianceByKey(ambianceKey);

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? accentKey,
    Color? customAccent,
    String? ambianceKey,
    bool? pureBlack,
    bool? reduceMotion,
    double? textScale,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentKey: accentKey ?? this.accentKey,
      customAccent: customAccent ?? this.customAccent,
      ambianceKey: ambianceKey ?? this.ambianceKey,
      pureBlack: pureBlack ?? this.pureBlack,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textScale: textScale ?? this.textScale,
    );
  }
}

// ── Notifier + persistance ─────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs) : super(_load(_prefs)) {
    AppMotion.reduce = state.reduceMotion;
  }

  final SharedPreferences _prefs;

  static const _kThemeMode = 'settings.themeMode';
  static const _kAccent = 'settings.accent';
  static const _kCustomAccent = 'settings.customAccent';
  static const _kAmbiance = 'settings.ambiance';
  static const _kPureBlack = 'settings.pureBlack';
  static const _kReduceMotion = 'settings.reduceMotion';
  static const _kTextScale = 'settings.textScale';

  static AppSettings _load(SharedPreferences prefs) {
    final modeIndex = prefs.getInt(_kThemeMode);
    final customValue = prefs.getInt(_kCustomAccent);
    return AppSettings(
      themeMode: modeIndex != null &&
              modeIndex >= 0 &&
              modeIndex < ThemeMode.values.length
          ? ThemeMode.values[modeIndex]
          : ThemeMode.system,
      accentKey: prefs.getString(_kAccent) ?? 'gold',
      customAccent: customValue != null ? Color(customValue) : null,
      ambianceKey: prefs.getString(_kAmbiance) ?? 'classic',
      pureBlack: prefs.getBool(_kPureBlack) ?? false,
      reduceMotion: prefs.getBool(_kReduceMotion) ?? false,
      textScale: prefs.getDouble(_kTextScale) ?? 1.0,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setInt(_kThemeMode, mode.index);
  }

  void setAccent(String key) {
    state = state.copyWith(accentKey: key);
    _prefs.setString(_kAccent, key);
  }

  /// Sélectionne une couleur d'accent libre (sélecteur multicolore).
  void setCustomAccent(Color color) {
    state = state.copyWith(accentKey: customAccentKey, customAccent: color);
    _prefs.setString(_kAccent, customAccentKey);
    _prefs.setInt(_kCustomAccent, color.toARGB32());
  }

  void setAmbiance(String key) {
    state = state.copyWith(ambianceKey: key);
    _prefs.setString(_kAmbiance, key);
  }

  void setPureBlack(bool value) {
    state = state.copyWith(pureBlack: value);
    _prefs.setBool(_kPureBlack, value);
  }

  void setReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    AppMotion.reduce = value;
    _prefs.setBool(_kReduceMotion, value);
  }

  void setTextScale(double value) {
    state = state.copyWith(textScale: value);
    _prefs.setDouble(_kTextScale, value);
  }

  void reset() {
    state = const AppSettings();
    AppMotion.reduce = false;
    _prefs.remove(_kThemeMode);
    _prefs.remove(_kAccent);
    _prefs.remove(_kCustomAccent);
    _prefs.remove(_kAmbiance);
    _prefs.remove(_kPureBlack);
    _prefs.remove(_kReduceMotion);
    _prefs.remove(_kTextScale);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

/// Accès global à la préférence "animations réduites" pour les widgets
/// d'animation feuilles, sans avoir à traverser tout l'arbre de providers.
class AppMotion {
  AppMotion._();

  static bool reduce = false;

  static Duration duration(Duration normal) =>
      reduce ? Duration.zero : normal;
}
