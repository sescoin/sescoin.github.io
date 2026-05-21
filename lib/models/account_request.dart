import '../core/constants.dart';

/// Demande de création de compte envoyée par un élève, en attente d'approbation prof
class AccountRequest {
  const AccountRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.status,
    required this.createdAt,
    this.avatarUrl,
    this.initialBalance,
    this.refusalReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String username; // prenom.nom généré automatiquement
  final AccountRequestStatus status;
  final DateTime createdAt;
  final String? avatarUrl;
  final double? initialBalance; // Défini par la prof à l'approbation
  final String? refusalReason;
  final DateTime? reviewedAt;
  final String? reviewedBy; // ID de l'admin qui a traité

  String get displayName => '$firstName $lastName';
  bool get isPending => status == AccountRequestStatus.pending;
  bool get isApproved => status == AccountRequestStatus.approved;
  bool get isRefused => status == AccountRequestStatus.refused;

  factory AccountRequest.fromJson(Map<String, dynamic> json) {
    return AccountRequest(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      username: json['username'] as String,
      status:
          AccountRequestStatusX.fromDb(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      avatarUrl: json['avatar_url'] as String?,
      initialBalance: json['initial_balance'] != null
          ? (json['initial_balance'] as num).toDouble()
          : null,
      refusalReason: json['refusal_reason'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'status': status.dbValue,
        'created_at': createdAt.toIso8601String(),
        'avatar_url': avatarUrl,
        'initial_balance': initialBalance,
        'refusal_reason': refusalReason,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by': reviewedBy,
      };

  AccountRequest copyWith({
    AccountRequestStatus? status,
    double? initialBalance,
    String? refusalReason,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return AccountRequest(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      status: status ?? this.status,
      createdAt: createdAt,
      avatarUrl: avatarUrl,
      initialBalance: initialBalance ?? this.initialBalance,
      refusalReason: refusalReason ?? this.refusalReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AccountRequest && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
