import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/settings_provider.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette de base ────────────────────────────────────────────────────────
  // Les surfaces (fonds, cartes, champs) viennent des ambiances :
  // voir appAmbiances dans settings_provider.dart.
  static const Color _primaryGold = Color(0xFFD4AF37); // Or SES Coin (défaut)
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _positive = Color(0xFF2ECC71);
  static const Color _negative = Color(0xFFE74C3C);

  /// Texte lisible par-dessus la couleur d'accent.
  static Color onAccent(Color accent) =>
      accent.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  /// Rapport de contraste WCAG entre deux couleurs (1 = identiques, 21 = max).
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// Rend [color] lisible sur [background] en ne touchant qu'à sa luminosité.
  ///
  /// L'accent sert aussi bien de fond de bouton que de couleur de texte et
  /// d'icône. Choisi trop proche de l'ambiance — ou simplement trop sombre
  /// sur un fond sombre — il rendait ces éléments invisibles. On préserve la
  /// teinte et la saturation choisies, et on éclaircit ou assombrit par pas
  /// successifs jusqu'à franchir le seuil de lisibilité.
  static Color _readableOn(Color color, Color background) {
    const minRatio = 3.0;
    if (_contrast(color, background) >= minRatio) return color;

    final lightenIt = background.computeLuminance() < 0.5;
    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 25; i++) {
      final next = (lightenIt ? hsl.lightness + 0.04 : hsl.lightness - 0.04)
          .clamp(0.0, 1.0);
      if (next == hsl.lightness) break; // butée atteinte
      hsl = hsl.withLightness(next);
      if (_contrast(hsl.toColor(), background) >= minRatio) break;
    }
    return hsl.toColor();
  }

  // ── Typographie ────────────────────────────────────────────────────────────
  // La famille choisie dans les réglages est appliquée d'abord, puis les
  // graisses et interlettrages propres à l'app : changer de police ne modifie
  // donc jamais la hiérarchie typographique.
  static TextTheme _textTheme(TextTheme base, String fontKey) =>
      applyAppFont(fontKey, base).copyWith(
        headlineLarge: base.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineMedium: base.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        headlineSmall: base.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleLarge: base.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: base.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
      );

  // ── Transitions de pages ───────────────────────────────────────────────────
  // FadeForwards = transition Material 3 moderne (fondu + glissement latéral).
  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  );

  // ── Thème clair ────────────────────────────────────────────────────────────
  static ThemeData light(
    AppAccent accent, {
    AppAmbiance? ambiance,
    String fontKey = 'system',
  }) {
    final amb = ambiance ?? appAmbiances.first;
    final scaffold = amb.lightScaffold;
    final input = amb.lightInput;
    final primary = _readableOn(accent.color, scaffold);
    final onPrimary = onAccent(primary);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent.dark,
      surface: Colors.white,
      error: _negative,
    );
    // Famille résolue une fois pour toutes. `ThemeData.fontFamily` ne suffit
    // pas : tout `TextStyle` défini explicitement plus bas (titre de barre,
    // libellés de boutons, info-bulles) remplace la famille au lieu d'en
    // hériter, et garderait donc la police du système.
    final family = appFontFamily(fontKey);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: family,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: _textTheme(base.textTheme, fontKey),
      pageTransitionsTheme: _pageTransitions,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.65), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _negative, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _negative, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        height: 66,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF9E9E9E),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: family,
            fontSize: 11,
            overflow: TextOverflow.ellipsis,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF9E9E9E),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF9E9E9E),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _ink,
        contentTextStyle: TextStyle(
          fontFamily: family,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: input,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: primary,
        indicatorColor: primary,
        unselectedLabelColor: const Color(0xFF8E8E93),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onAccent(primary) : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontFamily: family,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Thème sombre ───────────────────────────────────────────────────────────
  static ThemeData dark(
    AppAccent accent, {
    AppAmbiance? ambiance,
    String fontKey = 'system',
  }) {
    final amb = ambiance ?? appAmbiances.first;
    final scaffold = amb.darkScaffold;
    final surface = amb.darkSurface;
    final card = amb.darkCard;
    final input = amb.darkInput;
    final primary = _readableOn(accent.color, scaffold);
    final onPrimary = onAccent(primary);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent.dark,
      surface: surface,
      error: _negative,
    );
    // Famille résolue une fois pour toutes. `ThemeData.fontFamily` ne suffit
    // pas : tout `TextStyle` défini explicitement plus bas (titre de barre,
    // libellés de boutons, info-bulles) remplace la famille au lieu d'en
    // hériter, et garderait donc la police du système.
    final family = appFontFamily(fontKey);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: family,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: _textTheme(base.textTheme, fontKey),
      pageTransitionsTheme: _pageTransitions,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: card,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.3),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.6), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _negative, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _negative, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF6E6E8A)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        height: 66,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF6E6E8A),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: family,
            fontSize: 11,
            overflow: TextOverflow.ellipsis,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF6E6E8A),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF6E6E8A),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A3E),
        contentTextStyle: TextStyle(
          fontFamily: family,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: input,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.07),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: primary,
        indicatorColor: primary,
        unselectedLabelColor: const Color(0xFF8E8E93),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onAccent(primary) : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontFamily: family,
          color: _ink,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Couleurs sémantiques (accessibles partout) ────────────────────────────
  static const Color positive = _positive;
  static const Color negative = _negative;
  static const Color gold = _primaryGold;
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3B82F6);

  static Color positiveAmount(bool isPositive) =>
      isPositive ? _positive : _negative;
}

/// Extensions sur BuildContext pour accéder aux couleurs facilement
extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Couleur d'accent choisie par l'utilisateur (primary du thème actif).
  Color get accent => Theme.of(this).colorScheme.primary;

  /// Couleur lisible posée sur l'accent.
  Color get onAccent => Theme.of(this).colorScheme.onPrimary;
}
