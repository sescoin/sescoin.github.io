class ChatMessage {
  const ChatMessage({
    required this.id,
    this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    required this.isCensored,
    required this.isDeleted,
    required this.createdAt,
    required this.expiresAt,
    this.editedAt,
    this.classId,
    this.messageType = 'text',
    this.loanAmount,
    this.loanNote,
    this.loanInterestRate,
    this.loanDueDate,
    this.loanDurationMinutes,
    this.loanStatus,
    this.loanId,
    this.loanAcceptedBy,
    this.giftAmount,
    this.giftClaimedBy,
    this.giftClaimedUsername,
    this.giftClaimedAt,
  });

  final String id;
  final String? userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final bool isCensored;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? editedAt;
  final String? classId;
  final String messageType;
  final double? loanAmount;
  final String? loanNote;
  final double? loanInterestRate;
  final DateTime? loanDueDate;

  /// Durée demandée, quand l'emprunteur a choisi un délai plutôt qu'une date.
  /// L'échéance n'est alors connue qu'une fois le prêt accepté.
  final int? loanDurationMinutes;
  final String? loanStatus;
  final String? loanId;
  final String? loanAcceptedBy;
  final double? giftAmount;
  final String? giftClaimedBy;
  final String? giftClaimedUsername;
  final DateTime? giftClaimedAt;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isLoanRequest => messageType == 'loan_request';
  bool get isLoanRequestAccepted => isLoanRequest && loanStatus == 'accepted';
  bool get isGift => messageType == 'gift';
  bool get isGiftClaimed => isGift && giftClaimedBy != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      content: json['content'] as String? ?? '',
      isCensored: json['is_censored'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String).toLocal()
          : DateTime.now().add(const Duration(hours: 48)),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String).toLocal()
          : null,
      classId: json['class_id'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      loanAmount: json['loan_amount'] != null
          ? (json['loan_amount'] as num).toDouble()
          : null,
      loanNote: json['loan_note'] as String?,
      loanInterestRate: json['loan_interest_rate'] != null
          ? (json['loan_interest_rate'] as num).toDouble()
          : null,
      loanDueDate: json['loan_due_date'] != null
          ? DateTime.parse(json['loan_due_date'] as String).toLocal()
          : null,
      loanDurationMinutes: json['loan_duration_minutes'] as int?,
      loanStatus: json['loan_status'] as String?,
      loanId: json['loan_id'] as String?,
      loanAcceptedBy: json['loan_accepted_by'] as String?,
      giftAmount: json['gift_amount'] != null
          ? (json['gift_amount'] as num).toDouble()
          : null,
      giftClaimedBy: json['gift_claimed_by'] as String?,
      giftClaimedUsername: json['gift_claimed_username'] as String?,
      giftClaimedAt: json['gift_claimed_at'] != null
          ? DateTime.parse(json['gift_claimed_at'] as String).toLocal()
          : null,
    );
  }
}

class ChatSendResult {
  const ChatSendResult({
    required this.message,
    required this.warning,
    required this.warningCount,
    required this.muted,
  });

  final ChatMessage message;
  final bool warning;
  final int warningCount;
  final bool muted;

  factory ChatSendResult.fromJson(Map<String, dynamic> json) {
    return ChatSendResult(
      message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
      warning: json['warning'] as bool,
      warningCount: json['warning_count'] as int,
      muted: json['muted'] as bool,
    );
  }
}
