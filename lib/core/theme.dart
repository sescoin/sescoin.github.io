import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/settings_provider.dart';

class AppTheme {
  AppTheme._();

  // ── Palette de base ────────────────────────────────────────────────────────
  // Les surfaces (fonds, cartes, champs) viennent des ambiances :
  // voir appAmbiances dans settings_provider.dart.
  static const Color _primaryGold = Color(0xFFD4AF37); // Or SES Coin (défaut)
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _positive = Color(0xFF2ECC71);
  static const Color _negative = Color(0xFFE74C3C);

  // Surfaces noir pur (OLED)
  static const Color _blackScaffold = Color(0xFF000000);
  static const Color _blackSurface = Color(0xFF0B0C12);
  static const Color _blackCard = Color(0xFF101118);
  static const Color _blackInput = Color(0xFF16171F);

  /// Texte lisible par-dessus la couleur d'accent.
  static Color onAccent(Color accent) =>
      accent.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

  // ── Typographie ────────────────────────────────────────────────────────────
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
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
  static ThemeData light(AppAccent accent, {AppAmbiance? ambiance}) {
    final amb = ambiance ?? appAmbiances.first;
    final scaffold = amb.lightScaffold;
    final input = amb.lightInput;
    final primary = accent.color;
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
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: _textTheme(base.textTheme),
      pageTransitionsTheme: _pageTransitions,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // ── Thème sombre ───────────────────────────────────────────────────────────
  static ThemeData dark(
    AppAccent accent, {
    AppAmbiance? ambiance,
    bool pureBlack = false,
  }) {
    final amb = ambiance ?? appAmbiances.first;
    final primary = accent.color;
    final onPrimary = onAccent(primary);
    final scaffold = pureBlack ? _blackScaffold : amb.darkScaffold;
    final surface = pureBlack ? _blackSurface : amb.darkSurface;
    final card = pureBlack ? _blackCard : amb.darkCard;
    final input = pureBlack ? _blackInput : amb.darkInput;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent.dark,
      surface: surface,
      error: _negative,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: _textTheme(base.textTheme),
      pageTransitionsTheme: _pageTransitions,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
        textStyle: const TextStyle(color: _ink, fontSize: 12),
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
