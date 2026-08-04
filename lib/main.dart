import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remplace l'écran rouge de Flutter par une page d'erreur lisible.
  //
  // ATTENTION : ce hook n'a rien à voir avec le réseau ni avec Supabase.
  // Il se déclenche quand un widget lève une exception pendant son build
  // (null check, cast invalide, index hors limites, `late` non initialisé…).
  // On affiche donc la vraie exception : sans elle, impossible de savoir
  // quel widget a planté.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    _logError('widget-build', details.exception, details.stack);
    return _ErrorFallback(details: details);
  };

  // Toutes les erreurs du framework passent ici — y compris celles qui ne
  // cassent pas l'affichage et qui étaient donc totalement invisibles.
  FlutterError.onError = (details) {
    _logError('flutter', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // Erreurs asynchrones non rattrapées (Futures sans catch).
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _logError('async', error, stack);
    return true;
  };

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialisation Supabase
  // Les valeurs sont injectées via --dart-define au build
  // Ex: flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
  // Un échec ici est la SEULE vraie « connexion à la base impossible ».
  // Sans ce try/catch, l'exception remontait hors de main() et l'app
  // restait sur un écran blanc, sans jamais afficher de message.
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://lslimfbxdanahekybybq.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_9OGOA6drdIbJPRwtKq0Z6g_bLaQAUA8',
      ),
      debug: false, // Passe à true pour voir les logs réseau
    );
  } catch (error, stack) {
    _logError('supabase-init', error, stack);
    runApp(_StartupErrorApp(error: error.toString()));
    return;
  }

  // Quand le token JWT est renouvelé, on le transmet aux canaux Realtime
  // pour éviter l'erreur "InvalidJWTToken: Token has expired".
  // On profite aussi de cet listener pour traiter les prêts en retard.
  Timer? overdueTimer;
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.tokenRefreshed &&
        data.session != null) {
      Supabase.instance.client.realtime
          .setAuth(data.session!.accessToken);
    }
    if (data.event == AuthChangeEvent.signedIn) {
      _processOverdueLoans();
      overdueTimer?.cancel();
      overdueTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _processOverdueLoans(),
      );
    }
    if (data.event == AuthChangeEvent.signedOut) {
      overdueTimer?.cancel();
      overdueTimer = null;
    }
  });

  // Préférences locales (thème, accent, animations…)
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // ProviderScope = racine obligatoire pour Riverpod
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SESCoinApp(),
    ),
  );
}

/// Thème actuellement appliqué, mémorisé pour l'écran d'erreur.
///
/// `ErrorWidget.builder` est appelé en dehors de l'arbre de l'application :
/// il ne dispose d'aucun `BuildContext` utilisable pour retrouver le thème.
ThemeData? _activeTheme;

class SESCoinApp extends ConsumerWidget {
  const SESCoinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    final lightTheme = AppTheme.light(
      settings.accent,
      ambiance: settings.ambiance,
      fontKey: settings.fontKey,
    );
    final darkTheme = AppTheme.dark(
      settings.accent,
      ambiance: settings.ambiance,
      fontKey: settings.fontKey,
    );

    // L'écran d'erreur est construit hors de l'arbre de l'application : aucun
    // Theme n'est accessible depuis ErrorWidget.builder. On lui laisse donc
    // le thème actif, pour qu'il suive l'ambiance, l'accent et la police
    // choisis plutôt que des couleurs figées.
    final systemDark = WidgetsBinding.instance.platformDispatcher
            .platformBrightness ==
        Brightness.dark;
    _activeTheme = switch (settings.themeMode) {
      ThemeMode.dark => darkTheme,
      ThemeMode.light => lightTheme,
      ThemeMode.system => systemDark ? darkTheme : lightTheme,
    };

    return MaterialApp.router(
      title: 'SES Coin',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.themeMode,
      // Fondu doux quand on change de thème ou de couleur d'accent.
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: router,
      builder: (context, child) {
        // Taille de police = système (borné 0.8–1.2) × préférence utilisateur
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.scale(1.0).clamp(0.8, 1.2);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(clamped * settings.textScale),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Écran affiché quand Supabase n'a pas pu être initialisé au démarrage.
/// C'est le seul cas où le diagnostic « base de données injoignable » est
/// réellement exact.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: const Color(0xFF15172B),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Connexion à la base de données impossible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vérifier la connexion internet, puis relancer l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFB4A2),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Journalise une erreur au lieu de la faire disparaître silencieusement.
/// Visible dans la console du navigateur (F12) et dans `flutter run`.
/// Écran de repli affiché à la place d'un widget dont la construction a
/// échoué.
///
/// `ErrorWidget` remplace *chaque* widget fautif pris isolément : dans une
/// liste, vingt tuiles en échec produisent vingt écrans empilés. La
/// présentation s'adapte donc à la place disponible — une simple ligne dans
/// un espace contraint, l'écran complet sinon.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // Couleurs et police du thème actif : l'écran reste dans l'ambiance
    // choisie au lieu de trancher avec le reste de l'application.
    final theme = _activeTheme;
    final scheme = theme?.colorScheme;
    final background =
        theme?.scaffoldBackgroundColor ?? const Color(0xFF14161F);
    final accent = scheme?.primary ?? const Color(0xFFF5883C);
    final onAccent = scheme?.onPrimary ?? Colors.white;
    final onSurface = scheme?.onSurface ?? Colors.white;
    final muted = scheme?.onSurfaceVariant ?? const Color(0xFFA8AEC6);
    final family = theme?.textTheme.bodyMedium?.fontFamily;
    final isDark = background.computeLuminance() < 0.5;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 260;
          return Material(
            color: compact ? Colors.transparent : background,
            child: compact
                ? _line(muted, family)
                : _page(
                    accent: accent,
                    onAccent: onAccent,
                    onSurface: onSurface,
                    muted: muted,
                    family: family,
                    isDark: isDark,
                  ),
          );
        },
      ),
    );
  }

  /// Version réduite, pour un élément de liste ou une carte.
  Widget _line(Color muted, String? family) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 17, color: muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Élément non affiché',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: 13,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _page({
    required Color accent,
    required Color onAccent,
    required Color onSurface,
    required Color muted,
    required String? family,
    required bool isDark,
  }) {
    final message = details.exceptionAsString();

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 32, 26, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.report_problem_outlined,
                      size: 32,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Affichage impossible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cet élément n\'a pas pu être affiché. Revenir à l\'écran '
                  'précédent, puis relancer l\'application si le problème '
                  'persiste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: family,
                    color: muted,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                // Détail technique au second plan : utile pour signaler un
                // problème, discret pour qui ne le cherche pas.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.26)
                        : onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: onSurface.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal_rounded, size: 14, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Détail technique',
                              style: TextStyle(
                                fontFamily: family,
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Clipboard.setData(
                              ClipboardData(
                                text: '$message\n\n${details.stack}',
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Copier',
                                    style: TextStyle(
                                      fontFamily: family,
                                      color: accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      SelectableText(
                        message,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.72),
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _logError(String origin, Object error, StackTrace? stack) {
  debugPrint('┌─ [SESCoin/$origin] $error');
  if (stack != null) {
    final lines = stack.toString().split('\n').take(12);
    for (final line in lines) {
      debugPrint('│ $line');
    }
  }
  debugPrint('└─');
}

/// Raccourci global pour accéder au client Supabase
/// Usage: supabase.from('profiles').select()
final supabase = Supabase.instance.client;

void _processOverdueLoans() {
  Supabase.instance.client
      .rpc('process_overdue_loans')
      .then((_) {})
      .catchError((_) {});
}
