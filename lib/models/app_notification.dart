import '../core/text_sanitizer.dart';

enum NotificationType {
  transactionReceived,
  transactionSent,
  transactionConfirmationRequired,
  auctionOutbid,
  auctionWon,
  auctionEnded,
  loanRequested,
  loanAccepted,
  loanRejected,
  loanRepaid,
  loanOverdue,
  marketplacePurchase,
  accountApproved,
  accountRejected,
  adminTax,
  adminReward,
  system,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  String? get action => data?['action'] as String?;

  String? get targetUserId => data?['user_id'] as String?;

  bool get opensAvatarReview =>
      action == 'review_avatar' && targetUserId != null;

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'transaction_received':
        return NotificationType.transactionReceived;
      case 'transaction_sent':
        return NotificationType.transactionSent;
      case 'transaction_confirmation_required':
        return NotificationType.transactionConfirmationRequired;
      case 'auction_outbid':
        return NotificationType.auctionOutbid;
      case 'auction_won':
        return NotificationType.auctionWon;
      case 'auction_ended':
        return NotificationType.auctionEnded;
      case 'loan_requested':
        return NotificationType.loanRequested;
      case 'loan_accepted':
        return NotificationType.loanAccepted;
      case 'loan_rejected':
        return NotificationType.loanRejected;
      case 'loan_repaid':
        return NotificationType.loanRepaid;
      case 'loan_overdue':
        return NotificationType.loanOverdue;
      case 'marketplace_purchase':
        return NotificationType.marketplacePurchase;
      case 'account_approved':
        return NotificationType.accountApproved;
      case 'account_rejected':
        return NotificationType.accountRejected;
      case 'admin_tax':
        return NotificationType.adminTax;
      case 'admin_reward':
        return NotificationType.adminReward;
      default:
        return NotificationType.system;
    }
  }

  static String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.transactionReceived:
        return 'transaction_received';
      case NotificationType.transactionSent:
        return 'transaction_sent';
      case NotificationType.transactionConfirmationRequired:
        return 'transaction_confirmation_required';
      case NotificationType.auctionOutbid:
        return 'auction_outbid';
      case NotificationType.auctionWon:
        return 'auction_won';
      case NotificationType.auctionEnded:
        return 'auction_ended';
      case NotificationType.loanRequested:
        return 'loan_requested';
      case NotificationType.loanAccepted:
        return 'loan_accepted';
      case NotificationType.loanRejected:
        return 'loan_rejected';
      case NotificationType.loanRepaid:
        return 'loan_repaid';
      case NotificationType.loanOverdue:
        return 'loan_overdue';
      case NotificationType.marketplacePurchase:
        return 'marketplace_purchase';
      case NotificationType.accountApproved:
        return 'account_approved';
      case NotificationType.accountRejected:
        return 'account_rejected';
      case NotificationType.adminTax:
        return 'admin_tax';
      case NotificationType.adminReward:
        return 'admin_reward';
      case NotificationType.system:
        return 'system';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    String trimTrailingPeriod(String value) {
      final sanitized = TextSanitizer.clean(value).trim();
      if (sanitized.endsWith('.') &&
          !sanitized.endsWith('..') &&
          !sanitized.endsWith('...')) {
        return sanitized.substring(0, sanitized.length - 1).trimRight();
      }
      return sanitized;
    }

    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: _typeFromString(json['type'] as String),
      title: trimTrailingPeriod(json['title'] as String),
      body: trimTrailingPeriod(json['body'] as String),
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': _typeToString(type),
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AppNotification(id: $id, type: $type, title: $title, isRead: $isRead)';
}
