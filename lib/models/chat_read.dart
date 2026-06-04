class ChatRead {
  const ChatRead({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.lastReadMessageId,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? lastReadMessageId;

  factory ChatRead.fromJson(Map<String, dynamic> json) {
    return ChatRead(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      lastReadMessageId: json['last_read_message_id'] as String?,
    );
  }
}
