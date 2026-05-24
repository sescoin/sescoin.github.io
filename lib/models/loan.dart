import '../core/text_sanitizer.dart';

enum LoanStatus { pending, active, repaid, defaulted, rejected, cancelled }

class Loan {
  const Loan({
    required this.id,
    required this.lenderId,
    required this.lenderUsername,
    this.lenderAvatarUrl,
    required this.borrowerId,
    required this.borrowerUsername,
    this.borrowerAvatarUrl,
    required this.principal,
    required this.interestRate,
    required this.totalDue,
    required this.amountRepaid,
    required this.status,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String lenderId;
  final String lenderUsername;
  final String? lenderAvatarUrl;
  final String borrowerId;
  final String borrowerUsername;
  final String? borrowerAvatarUrl;
  final double principal;
  final double interestRate;
  final double totalDue;
  final double amountRepaid;
  final LoanStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;

  double get remainingAmount => totalDue - amountRepaid;
  double get interestAmount => totalDue - principal;
  bool get isFullyRepaid => amountRepaid >= totalDue;
  bool get isActive => status == LoanStatus.active;
  bool get isPending => status == LoanStatus.pending;
  bool get isArchived =>
      status == LoanStatus.repaid ||
      status == LoanStatus.rejected ||
      status == LoanStatus.cancelled ||
      status == LoanStatus.defaulted;

  bool get isOverdue =>
      isActive && dueDate != null && DateTime.now().isAfter(dueDate!);

  double get repaymentProgress =>
      totalDue > 0 ? (amountRepaid / totalDue).clamp(0.0, 1.0) : 0.0;

  static double calculateTotalDue(double principal, double interestRate) {
    return principal * (1 + interestRate / 100);
  }

  static LoanStatus _statusFromString(String value) {
    switch (value) {
      case 'pending':
        return LoanStatus.pending;
      case 'active':
        return LoanStatus.active;
      case 'repaid':
        return LoanStatus.repaid;
      case 'defaulted':
        return LoanStatus.defaulted;
      case 'rejected':
        return LoanStatus.rejected;
      case 'cancelled':
        return LoanStatus.cancelled;
      default:
        return LoanStatus.pending;
    }
  }

  static String _statusToString(LoanStatus value) {
    switch (value) {
      case LoanStatus.pending:
        return 'pending';
      case LoanStatus.active:
        return 'active';
      case LoanStatus.repaid:
        return 'repaid';
      case LoanStatus.defaulted:
        return 'defaulted';
      case LoanStatus.rejected:
        return 'rejected';
      case LoanStatus.cancelled:
        return 'cancelled';
    }
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String,
      lenderId: json['lender_id'] as String,
      lenderUsername: json['lender_username'] as String,
      lenderAvatarUrl: (json['lender_profile'] as Map<String, dynamic>?)?['avatar_url']
          as String?,
      borrowerId: json['borrower_id'] as String,
      borrowerUsername: json['borrower_username'] as String,
      borrowerAvatarUrl:
          (json['borrower_profile'] as Map<String, dynamic>?)?['avatar_url']
              as String?,
      principal: (json['principal'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      totalDue: (json['total_due'] as num).toDouble(),
      amountRepaid: (json['amount_repaid'] as num).toDouble(),
      status: _statusFromString(json['status'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      note: TextSanitizer.nullable(json['note'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lender_id': lenderId,
      'lender_username': lenderUsername,
      'lender_avatar_url': lenderAvatarUrl,
      'borrower_id': borrowerId,
      'borrower_username': borrowerUsername,
      'borrower_avatar_url': borrowerAvatarUrl,
      'principal': principal,
      'interest_rate': interestRate,
      'total_due': totalDue,
      'amount_repaid': amountRepaid,
      'status': _statusToString(status),
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'note': note,
    };
  }

  Loan copyWith({
    String? id,
    String? lenderId,
    String? lenderUsername,
    String? lenderAvatarUrl,
    String? borrowerId,
    String? borrowerUsername,
    String? borrowerAvatarUrl,
    double? principal,
    double? interestRate,
    double? totalDue,
    double? amountRepaid,
    LoanStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
  }) {
    return Loan(
      id: id ?? this.id,
      lenderId: lenderId ?? this.lenderId,
      lenderUsername: lenderUsername ?? this.lenderUsername,
      lenderAvatarUrl: lenderAvatarUrl ?? this.lenderAvatarUrl,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerUsername: borrowerUsername ?? this.borrowerUsername,
      borrowerAvatarUrl: borrowerAvatarUrl ?? this.borrowerAvatarUrl,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      totalDue: totalDue ?? this.totalDue,
      amountRepaid: amountRepaid ?? this.amountRepaid,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Loan && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Loan(id: $id, borrower: $borrowerUsername, principal: $principal, status: $status)';
  }
}
