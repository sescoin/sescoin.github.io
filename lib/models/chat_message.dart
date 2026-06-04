class ChatMessage {
  const ChatMessage({
    required this.id,
    this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    required this.isCensored,
    required this.createdAt,
    required this.savedBy,
    required this.expiresAt,
  });

  final String id;
  final String? userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final bool isCensored;
  final DateTime createdAt;
  final List<String> savedBy;
  final DateTime expiresAt;

  bool get isExpired =>
      savedBy.isEmpty && expiresAt.isBefore(DateTime.now());

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      content: json['content'] as String,
      isCensored: json['is_censored'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      savedBy: (json['saved_by'] as List<dynamic>?)?.cast<String>() ?? [],
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String).toLocal()
          : DateTime.now().add(const Duration(hours: 24)),
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
