import '../core/text_sanitizer.dart';

/// Signalement d'un message de chat, adressé à l'administration.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.reporterUsername,
    required this.reportedId,
    required this.reportedUsername,
    required this.messageContent,
    required this.status,
    required this.createdAt,
    this.messageId,
    this.classId,
    this.reviewedAt,
  });

  final String id;
  final String reporterId;
  final String reporterUsername;
  final String reportedId;
  final String reportedUsername;

  /// Copie du message au moment du signalement : l'original peut avoir été
  /// modifié ou supprimé depuis.
  final String messageContent;

  /// `pending`, `reviewed` ou `dismissed`.
  final String status;
  final DateTime createdAt;

  /// Nul si le message d'origine a été supprimé.
  final String? messageId;
  final String? classId;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';

  /// Le message venait d'un chat de classe plutôt que des annonces.
  bool get isClassChat => classId != null;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reporterUsername: json['reporter_username'] as String,
      reportedId: json['reported_id'] as String,
      reportedUsername: json['reported_username'] as String,
      messageContent: TextSanitizer.clean(json['message_content'] as String),
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      messageId: json['message_id'] as String?,
      classId: json['class_id'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
    );
  }
}
