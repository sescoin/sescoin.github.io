const _sentinel = Object();

/// Profil d'un utilisateur SES Coin
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.balance,
    required this.role,
    required this.isBanned,
    required this.createdAt,
    this.avatarUrl,
    this.pendingAvatarUrl,
    this.fcmToken,
  });

  final String id; // UUID Supabase auth
  final String username; // prenom.nom (unique)
  final String displayName; // Prénom Nom (avec accents)
  final double balance;
  final String role; // 'student' | 'admin'
  final bool isBanned;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? pendingAvatarUrl;
  final String? fcmToken; // Pour notifications push

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';

  /// Solde formaté : "1 234,56 SC"
  String get formattedBalance {
    final formatted = balance.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '$formatted SC';
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      balance: (json['balance'] as num).toDouble(),
      role: json['role'] as String? ?? 'student',
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      avatarUrl: json['avatar_url'] as String?,
      pendingAvatarUrl: json['pending_avatar_url'] as String?,
      fcmToken: json['fcm_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'balance': balance,
        'role': role,
        'is_banned': isBanned,
        'created_at': createdAt.toIso8601String(),
        'avatar_url': avatarUrl,
        'pending_avatar_url': pendingAvatarUrl,
        'fcm_token': fcmToken,
      };

  Profile copyWith({
    String? id,
    String? username,
    String? displayName,
    double? balance,
    String? role,
    bool? isBanned,
    DateTime? createdAt,
    String? avatarUrl,
    Object? pendingAvatarUrl = _sentinel,
    String? fcmToken,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      balance: balance ?? this.balance,
      role: role ?? this.role,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pendingAvatarUrl: pendingAvatarUrl == _sentinel
          ? this.pendingAvatarUrl
          : pendingAvatarUrl as String?,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Profile(username: $username, balance: $balance SC)';
}

/// Version allégée pour le leaderboard et les listes
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.username,
    required this.displayName,
    required this.balance,
    this.avatarUrl,
    this.rank,
  });

  final String id;
  final String username;
  final String displayName;
  final double balance;
  final String? avatarUrl;
  final int? rank;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      balance: (json['balance'] as num).toDouble(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  factory ProfileSummary.fromProfile(Profile p, {int? rank}) {
    return ProfileSummary(
      id: p.id,
      username: p.username,
      displayName: p.displayName,
      balance: p.balance,
      avatarUrl: p.avatarUrl,
      rank: rank,
    );
  }
}
