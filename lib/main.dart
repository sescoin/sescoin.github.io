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
    final message = details.exceptionAsString();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF14161F),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 32, 26, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pastille dans les couleurs de l'app plutôt qu'une icône
                    // de débogage posée à nu.
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7C948), Color(0xFFE1502F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFE1502F).withValues(alpha: 0.38),
                              blurRadius: 26,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Une erreur est survenue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cette partie de l\'application n\'a pas pu s\'afficher. '
                      'Revenir en arrière, puis relancer l\'application si le '
                      'problème se répète.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFA8AEC6),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Détail technique relégué au second plan : utile pour
                    // remonter un bug, invisible pour qui ne le cherche pas.
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.terminal_rounded,
                                size: 14,
                                color: Color(0xFF767C99),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Détail technique',
                                  style: TextStyle(
                                    color: Color(0xFF767C99),
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
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 13,
                                        color: Color(0xFF9AA0BC),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Copier',
                                        style: TextStyle(
                                          color: Color(0xFF9AA0BC),
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
                            style: const TextStyle(
                              color: Color(0xFFE79A86),
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
        ),
      ),
    );
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

class SESCoinApp extends ConsumerWidget {
  const SESCoinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'SES Coin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        settings.accent,
        ambiance: settings.ambiance,
        fontKey: settings.fontKey,
      ),
      darkTheme: AppTheme.dark(
        settings.accent,
        ambiance: settings.ambiance,
        fontKey: settings.fontKey,
      ),
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
