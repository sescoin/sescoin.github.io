import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/maintenance_status.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

/// Maintenance vue par cet appareil : faut-il afficher l'écran de
/// maintenance, ou le bandeau de la session de maintenance ?
final maintenanceProvider =
    StateNotifierProvider<MaintenanceNotifier, MaintenanceStatus>((ref) {
  return MaintenanceNotifier(ref);
});

class MaintenanceNotifier extends StateNotifier<MaintenanceStatus> {
  MaintenanceNotifier(this._ref) : super(MaintenanceStatus.none) {
    _restoreCache();
    _listen();
    unawaited(refresh());
  }

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<MaintenanceMode>? _modeSub;
  AppLifecycleListener? _lifecycle;
  Timer? _poll;
  Duration? _pollInterval;
  Future<void>? _inFlight;
  bool _again = false;

  static const _kBlocked = 'maintenance.blocked';
  static const _kMode = 'maintenance.mode';

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  bool get _signedIn => _client.auth.currentSession != null;

  /// Au démarrage, reprend le dernier état connu : un compte bloqué ne doit
  /// pas entrevoir l'application le temps de la première vérification.
  void _restoreCache() {
    if (!_signedIn) return;
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_kBlocked) ?? false) {
      state = MaintenanceStatus(
        mode: MaintenanceMode.values.asNameMap()[prefs.getString(_kMode)] ??
            MaintenanceMode.global,
        blocked: true,
      );
    }
  }

  void _listen() {
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedOut:
          _apply(MaintenanceStatus(mode: state.mode));
        case AuthChangeEvent.signedIn:
          // Maintenance générale en cours : le compte qui vient de se
          // connecter est bloqué d'office, plutôt que d'entrevoir l'accueil
          // le temps de la vérification.
          if (state.mode == MaintenanceMode.global &&
              !state.isMaintenanceSession) {
            _apply(state.copyWith(blocked: true));
          }
          unawaited(refresh());
        default:
          break;
      }
    });

    _modeSub = _ref.read(maintenanceServiceProvider).watchMode().listen(
      (mode) {
        if (_signedIn) {
          unawaited(refresh());
        } else {
          _apply(MaintenanceStatus(mode: mode));
        }
      },
      // Table absente (migration non appliquée) ou temps réel coupé : la
      // vérification périodique prend le relais.
      onError: (Object _) {},
    );

    _lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    _schedulePoll();
  }

  /// Interroge la base. Les demandes qui se chevauchent sont regroupées.
  Future<void> refresh() {
    final running = _inFlight;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _run().whenComplete(() {
      _inFlight = null;
      if (_again && mounted) {
        _again = false;
        unawaited(refresh());
      }
    });
    _inFlight = run;
    return run;
  }

  Future<void> _run() async {
    if (!_signedIn) {
      _apply(MaintenanceStatus(mode: state.mode));
      return;
    }
    try {
      final status = await _ref.read(maintenanceServiceProvider).fetchStatus();
      // Déconnecté pendant la requête : la réponse ne le concerne plus.
      if (_signedIn) _apply(status);
    } catch (_) {
      // Base injoignable, ou pas encore équipée : l'état connu est conservé.
    }
  }

  void _apply(MaintenanceStatus next) {
    if (!mounted) return;
    if (next != state) state = next;

    final prefs = _ref.read(sharedPreferencesProvider);
    if ((prefs.getBool(_kBlocked) ?? false) != next.blocked) {
      prefs.setBool(_kBlocked, next.blocked);
    }
    if (prefs.getString(_kMode) != next.mode.name) {
      prefs.setString(_kMode, next.mode.name);
    }
    _schedulePoll();
  }

  /// Filet de sécurité si le temps réel décroche. Plus serré tant que
  /// l'écran de maintenance est affiché, pour rendre la main sans délai.
  void _schedulePoll() {
    final interval = state.blocked
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60);
    if (_poll != null && _pollInterval == interval) return;
    _poll?.cancel();
    _pollInterval = interval;
    _poll = Timer.periodic(interval, (_) {
      if (_signedIn) unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _modeSub?.cancel();
    _lifecycle?.dispose();
    _poll?.cancel();
    super.dispose();
  }
}
