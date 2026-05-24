import '../core/constants.dart';
import '../core/text_sanitizer.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.fromUsername,
    this.toUsername,
    this.fromDisplayName,
    this.toDisplayName,
    this.description,
    this.metadata,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final TransactionType type;
  final DateTime createdAt;
  final String? fromUsername;
  final String? toUsername;
  final String? fromDisplayName;
  final String? toDisplayName;
  final String? description;
  final Map<String, dynamic>? metadata;

  String? get paymentMethod {
    final value = metadata?['payment_method'];
    return value is String ? value.toLowerCase() : null;
  }

  String? get paymentMethodLabel => switch (paymentMethod) {
        'nfc' => 'NFC',
        'qr' => 'QR',
        _ => null,
      };

  String? get marketplaceItemName {
    final value = metadata?['item_name'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  String? get auctionItemName {
    final value = metadata?['auction_item_name'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  bool isCredit(String userId) => toUserId == userId;

  bool isDebit(String userId) => fromUserId == userId;

  double signedAmount(String userId) => isCredit(userId) ? amount : -amount;

  String? otherPartyName(String userId) {
    if (isCredit(userId)) {
      return fromDisplayName ?? fromUsername;
    }
    return toDisplayName ?? toUsername;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final fromProfile = json['from_profile'] as Map<String, dynamic>?;
    final toProfile = json['to_profile'] as Map<String, dynamic>?;

    return Transaction(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionTypeX.fromDb(json['type'] as String? ?? 'transfer'),
      createdAt: DateTime.parse(json['created_at'] as String),
      fromUsername: fromProfile?['username'] as String? ??
          json['from_username'] as String?,
      toUsername:
          toProfile?['username'] as String? ?? json['to_username'] as String?,
      fromDisplayName: fromProfile?['display_name'] as String? ??
          json['from_display_name'] as String?,
      toDisplayName: toProfile?['display_name'] as String? ??
          json['to_display_name'] as String?,
      description: TextSanitizer.nullable(json['description'] as String?),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'type': type.dbValue,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Transaction && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Transaction(${type.label}: $amount SC)';
}
