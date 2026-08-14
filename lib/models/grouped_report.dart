import '../core/text_sanitizer.dart';

/// Signalements d'un même message, agrégés par la base.
///
/// Un message très signalé compte pour une seule entrée, avec la liste de
/// ceux qui l'ont remonté — c'est ce nombre qui donne l'ordre de traitement.
class GroupedReport {
  const GroupedReport({
    required this.reportedId,
    required this.reportedUsername,
    required this.messageContent,
    required this.reportCount,
    required this.pendingCount,
    required this.reporters,
    required this.reportIds,
    required this.firstReportedAt,
    required this.lastReportedAt,
    this.messageId,
    this.classId,
  });

  final String reportedId;
  final String reportedUsername;
  final String messageContent;

  /// Nombre total de signalements reçus par ce message.
  final int reportCount;

  /// Parmi eux, ceux qui restent à traiter.
  final int pendingCount;

  final List<String> reporters;
  final List<String> reportIds;
  final DateTime firstReportedAt;
  final DateTime lastReportedAt;

  /// Nul si le message d'origine a été supprimé de la base.
  final String? messageId;

  /// Nul pour le chat des annonces.
  final String? classId;

  bool get isPending => pendingCount > 0;
  bool get isClassChat => classId != null;

  factory GroupedReport.fromJson(Map<String, dynamic> json) {
    return GroupedReport(
      reportedId: json['reported_id'] as String,
      reportedUsername: json['reported_username'] as String,
      messageContent: TextSanitizer.clean(json['message_content'] as String),
      reportCount: (json['report_count'] as num).toInt(),
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      reporters: ((json['reporters'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      reportIds: ((json['report_ids'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      firstReportedAt: DateTime.parse(json['first_reported_at'] as String),
      lastReportedAt: DateTime.parse(json['last_reported_at'] as String),
      messageId: json['message_id'] as String?,
      classId: json['class_id'] as String?,
    );
  }
}

/// Une ligne de la transcription d'un chat, telle que servie à l'export.
class TranscriptLine {
  const TranscriptLine({
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.content,
    required this.isDeleted,
    required this.isCensored,
    this.originalContent,
    this.editedAt,
    this.messageType,
  });

  final DateTime createdAt;
  final String username;
  final String displayName;
  final String content;
  final bool isDeleted;
  final bool isCensored;

  /// Contenu avant la première modification, s'il y en a eu une.
  final String? originalContent;
  final DateTime? editedAt;
  final String? messageType;

  factory TranscriptLine.fromJson(Map<String, dynamic> json) {
    return TranscriptLine(
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String,
      displayName: TextSanitizer.clean(json['display_name'] as String),
      content: TextSanitizer.clean(json['content'] as String? ?? ''),
      isDeleted: json['is_deleted'] as bool? ?? false,
      isCensored: json['is_censored'] as bool? ?? false,
      originalContent: TextSanitizer.nullable(
        json['original_content'] as String?,
      ),
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      messageType: json['message_type'] as String?,
    );
  }
}
