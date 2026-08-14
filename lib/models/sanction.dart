import '../core/text_sanitizer.dart';

/// Mesure prise contre un compte, automatique ou décidée par l'administrateur.
class Sanction {
  const Sanction({
    required this.id,
    required this.userId,
    required this.username,
    required this.kind,
    required this.automatic,
    required this.createdAt,
    this.reason,
    this.until,
    this.issuedByUsername,
  });

  final String id;
  final String userId;
  final String username;

  /// `mute`, `ban`, `unban` ou `warning`.
  final String kind;

  /// Vrai lorsque la mesure découle du filtre ou d'un seuil, sans
  /// intervention humaine.
  final bool automatic;

  final DateTime createdAt;
  final String? reason;

  /// Terme de la mesure. Nul si elle est définitive ou instantanée.
  final DateTime? until;
  final String? issuedByUsername;

  bool get isActive => until != null && until!.isAfter(DateTime.now());

  String get label => switch (kind) {
        'mute' => 'Chat suspendu',
        'ban' => 'Compte suspendu',
        'unban' => 'Suspension levée',
        _ => 'Avertissement',
      };

  factory Sanction.fromJson(Map<String, dynamic> json) {
    return Sanction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      kind: json['kind'] as String,
      automatic: json['automatic'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      reason: TextSanitizer.nullable(json['reason'] as String?),
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
      issuedByUsername: json['issued_by_username'] as String?,
    );
  }
}
