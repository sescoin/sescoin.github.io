import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/loan.dart';
import '../models/loan_config.dart';

class LoanService {
  LoanService(this._client);

  final SupabaseClient _client;
  static const _loanSelect = '''
    *,
    lender_profile:profiles!lender_id(avatar_url),
    borrower_profile:profiles!borrower_id(avatar_url)
  ''';

  Future<void> processOverdueLoans() async {
    try {
      await _client.rpc('process_overdue_loans');
    } on PostgrestException {
      // traitement silencieux, non bloquant
    }
  }

  Future<List<Loan>> getBorrowedLoans(String userId) async {
    await processOverdueLoans();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .eq('borrower_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getLentLoans(String userId) async {
    await processOverdueLoans();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .eq('lender_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getAllUserLoans(String userId) async {
    await processOverdueLoans();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .or('borrower_id.eq.$userId,lender_id.eq.$userId')
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getOverdueLoans() async {
    await processOverdueLoans();
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .eq('status', 'active')
        .lt('due_date', now)
        .order('due_date', ascending: true);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<Loan> getLoan(String loanId) async {
    await processOverdueLoans();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .eq('id', loanId)
        .single();

    return Loan.fromJson(data);
  }

  Future<int> countActiveBorrowedLoans(String borrowerId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select('id')
        .eq('borrower_id', borrowerId)
        .inFilter('status', ['pending', 'active']);
    return (data as List).length;
  }

  Future<List<Loan>> getAllLoansAdmin() async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select(_loanSelect)
        .order('created_at', ascending: false);
    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<LoanConfig> getLoanConfig() async {
    try {
      final data = await _client
          .from('loan_config')
          .select()
          .eq('id', 1)
          .single();
      return LoanConfig.fromJson(data);
    } on PostgrestException {
      return LoanConfig.defaults;
    }
  }

  Future<void> updateLoanConfig(LoanConfig config) async {
    try {
      await _client.rpc('update_loan_config', params: {
        'p_max_daily_sc': config.maxDailySc,
        'p_max_weekly_sc': config.maxWeeklySc,
        'p_max_active_loans': config.maxActiveLoans,
        'p_max_duration_days': config.maxDurationDays,
        'p_max_interest_rate': config.maxInterestRate,
        'p_min_balance_sc': config.minBalanceSc,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> requestLoan({
    required String borrowerId,
    required String lenderUsername,
    required double principal,
    required double interestRate,
    DateTime? dueDate,
    String? note,
  }) async {
    await processOverdueLoans();

    if (principal < AppConstants.minTransferAmount) {
      throw Exception('Montant minimum : ${AppConstants.minTransferAmount} SC');
    }
    if (interestRate < AppConstants.minLoanInterestRate ||
        interestRate > AppConstants.maxLoanInterestRate) {
      throw Exception(
        'Taux entre ${AppConstants.minLoanInterestRate}% et ${AppConstants.maxLoanInterestRate}%',
      );
    }
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      throw Exception('La date d\'échéance doit être dans le futur.');
    }
    if (dueDate != null) {
      final maxDue = DateTime.now().add(Duration(days: AppConstants.maxLoanDurationDays));
      if (dueDate.isAfter(maxDue)) {
        throw Exception(
          'L\'échéance ne peut pas dépasser ${AppConstants.maxLoanDurationDays} jours.',
        );
      }
    }

    final activeLoans = await _client
        .from(AppConstants.tableLoans)
        .select('id')
        .eq('borrower_id', borrowerId)
        .inFilter('status', ['pending', 'active']);
    if ((activeLoans as List).length >= AppConstants.maxActiveLoansBorrowed) {
      throw Exception(
        'Tu as déjà ${AppConstants.maxActiveLoansBorrowed} prêts actifs ou en attente. Rembourse-en un avant d\'en demander un nouveau.',
      );
    }

    final lenderData = await _client
        .from(AppConstants.tableProfiles)
        .select('id, username, role')
        .eq('username', lenderUsername)
        .eq('is_banned', false)
        .maybeSingle();

    if (lenderData == null) {
      throw Exception('Aucun compte actif trouvé pour "$lenderUsername".');
    }
    if (lenderData['id'] == borrowerId) {
      throw Exception('Impossible de se prêter à soi-même.');
    }
    if (lenderData['role'] == 'admin') {
      throw Exception('Impossible de demander un prêt à un administrateur.');
    }

    final totalDue = Loan.calculateTotalDue(principal, interestRate);
    try {
      final data = await _client.rpc('request_loan', params: {
        'p_borrower_id': borrowerId,
        'p_lender_id': lenderData['id'],
        'p_principal': principal,
        'p_interest_rate': interestRate,
        'p_total_due': totalDue,
        'p_due_date': dueDate?.toUtc().toIso8601String(),
        'p_note': note,
      });
      return Loan.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> acceptLoan(String loanId, String lenderId) async {
    try {
      final data = await _client.rpc('accept_loan', params: {
        'p_loan_id': loanId,
        'p_lender_id': lenderId,
      });
      return Loan.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> rejectLoan(String loanId, String lenderId) async {
    try {
      final data = await _client.rpc('reject_loan', params: {
        'p_loan_id': loanId,
        'p_lender_id': lenderId,
      });
      return Loan.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> cancelLoan(String loanId, String borrowerId) async {
    try {
      final data = await _client.rpc('cancel_loan', params: {
        'p_loan_id': loanId,
        'p_borrower_id': borrowerId,
      });
      return Loan.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deleteLoan(String loanId) async {
    try {
      await _client.rpc('delete_loan', params: {
        'p_loan_id': loanId,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> repayLoan({
    required String loanId,
    required String borrowerId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant de remboursement doit être positif.');
    }
    try {
      final data = await _client.rpc('repay_loan', params: {
        'p_loan_id': loanId,
        'p_borrower_id': borrowerId,
        'p_amount': amount,
      });
      return Loan.fromJson(data as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Loan> markAsDefaulted(String loanId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .update({
          'status': 'defaulted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', loanId)
        .select()
        .single();

    return Loan.fromJson(data);
  }

  Stream<List<Loan>> watchUserLoans(String userId) {
    return _client
        .from(AppConstants.tableLoans)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          await processOverdueLoans();
          final filtered = rows
              .where(
                (row) =>
                    row['borrower_id'] == userId || row['lender_id'] == userId,
              )
              .toList();
          if (filtered.isEmpty) {
            return <Loan>[];
          }

          final profileIds = <String>{
            for (final row in filtered) row['borrower_id'] as String,
            for (final row in filtered) row['lender_id'] as String,
          }.toList();

          final profiles = await _client
              .from(AppConstants.tableProfiles)
              .select('id, avatar_url')
              .inFilter('id', profileIds);

          final avatarById = <String, String?>{};
          for (final profile in profiles as List) {
            avatarById[profile['id'] as String] =
                profile['avatar_url'] as String?;
          }

          return filtered
              .map(
                (row) => Loan.fromJson({
                  ...row,
                  'lender_profile': {
                    'avatar_url': avatarById[row['lender_id'] as String],
                  },
                  'borrower_profile': {
                    'avatar_url': avatarById[row['borrower_id'] as String],
                  },
                }),
              )
              .toList();
        });
  }
}
