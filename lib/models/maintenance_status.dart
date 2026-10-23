/// Mode de maintenance publié par la table `maintenance_state`.
enum MaintenanceMode {
  off,

  /// Les accès administrateur autres que la session de maintenance sont
  /// suspendus ; les élèves ne voient rien.
  admin,

  /// Toutes les sessions autres que celle de maintenance sont suspendues.
  global;

  static MaintenanceMode fromDb(String? value) => switch (value) {
        'admin' => MaintenanceMode.admin,
        'global' => MaintenanceMode.global,
        _ => MaintenanceMode.off,
      };
}

/// Situation de cet appareil face à la maintenance.
class MaintenanceStatus {
  const MaintenanceStatus({
    this.mode = MaintenanceMode.off,
    this.blocked = false,
    this.isMaintenanceSession = false,
    this.startedAt,
  });

  static const none = MaintenanceStatus();

  final MaintenanceMode mode;

  /// Vrai quand cette session doit afficher l'écran de maintenance.
  final bool blocked;

  /// Vrai pour la session ouverte avec un mot de passe de maintenance.
  final bool isMaintenanceSession;

  final DateTime? startedAt;

  bool get isActive => mode != MaintenanceMode.off;

  factory MaintenanceStatus.fromJson(Map<String, dynamic> json) {
    final started = json['started_at'] as String?;
    return MaintenanceStatus(
      mode: MaintenanceMode.fromDb(json['mode'] as String?),
      blocked: json['blocked'] as bool? ?? false,
      isMaintenanceSession: json['is_maintenance_session'] as bool? ?? false,
      startedAt: started == null ? null : DateTime.parse(started).toLocal(),
    );
  }

  MaintenanceStatus copyWith({
    MaintenanceMode? mode,
    bool? blocked,
    bool? isMaintenanceSession,
  }) {
    return MaintenanceStatus(
      mode: mode ?? this.mode,
      blocked: blocked ?? this.blocked,
      isMaintenanceSession: isMaintenanceSession ?? this.isMaintenanceSession,
      startedAt: startedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceStatus &&
          other.mode == mode &&
          other.blocked == blocked &&
          other.isMaintenanceSession == isMaintenanceSession &&
          other.startedAt == startedAt;

  @override
  int get hashCode =>
      Object.hash(mode, blocked, isMaintenanceSession, startedAt);
}

/// Accès à usage unique délivré par `maintenance_request_access`.
class MaintenanceAccess {
  const MaintenanceAccess({
    required this.ticket,
    required this.secret,
    required this.email,
    required this.mode,
  });

  final String ticket;

  /// Secret aléatoire posé à la place du vrai mot de passe, le temps de la
  /// connexion.
  final String secret;

  final String email;
  final MaintenanceMode mode;

  factory MaintenanceAccess.fromJson(Map<String, dynamic> json) {
    return MaintenanceAccess(
      ticket: json['ticket'] as String,
      secret: json['secret'] as String,
      email: json['email'] as String,
      mode: MaintenanceMode.fromDb(json['mode'] as String?),
    );
  }
}
