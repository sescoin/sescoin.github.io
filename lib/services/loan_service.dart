import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/loan.dart';

class LoanService {
  LoanService(this._client);

  final SupabaseClient _client;

  Future<List<Loan>> getBorrowedLoans(String userId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select()
        .eq('borrower_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getLentLoans(String userId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select()
        .eq('lender_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getAllUserLoans(String userId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select()
        .or('borrower_id.eq.$userId,lender_id.eq.$userId')
        .order('created_at', ascending: false);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<List<Loan>> getOverdueLoans() async {
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from(AppConstants.tableLoans)
        .select()
        .eq('status', 'active')
        .lt('due_date', now)
        .order('due_date', ascending: true);

    return (data as List).map((row) => Loan.fromJson(row)).toList();
  }

  Future<Loan> getLoan(String loanId) async {
    final data = await _client
        .from(AppConstants.tableLoans)
        .select()
        .eq('id', loanId)
        .single();

    return Loan.fromJson(data);
  }

  Future<Loan> requestLoan({
    required String borrowerId,
    required String lenderUsername,
    required double principal,
    required double interestRate,
    DateTime? dueDate,
    String? note,
  }) async {
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
    final data = await _client.rpc('request_loan', params: {
      'p_borrower_id': borrowerId,
      'p_lender_id': lenderData['id'],
      'p_principal': principal,
      'p_interest_rate': interestRate,
      'p_total_due': totalDue,
      'p_due_date': dueDate?.toIso8601String(),
      'p_note': note,
    });

    return Loan.fromJson(data as Map<String, dynamic>);
  }

  Future<Loan> acceptLoan(String loanId, String lenderId) async {
    final data = await _client.rpc('accept_loan', params: {
      'p_loan_id': loanId,
      'p_lender_id': lenderId,
    });

    return Loan.fromJson(data as Map<String, dynamic>);
  }

  Future<Loan> rejectLoan(String loanId, String lenderId) async {
    final data = await _client.rpc('reject_loan', params: {
      'p_loan_id': loanId,
      'p_lender_id': lenderId,
    });

    return Loan.fromJson(data as Map<String, dynamic>);
  }

  Future<Loan> cancelLoan(String loanId, String borrowerId) async {
    final data = await _client.rpc('cancel_loan', params: {
      'p_loan_id': loanId,
      'p_borrower_id': borrowerId,
    });

    return Loan.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteLoan(String loanId) async {
    await _client.rpc('delete_loan', params: {
      'p_loan_id': loanId,
    });
  }

  Future<Loan> repayLoan({
    required String loanId,
    required String borrowerId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant de remboursement doit être positif.');
    }

    final data = await _client.rpc('repay_loan', params: {
      'p_loan_id': loanId,
      'p_borrower_id': borrowerId,
      'p_amount': amount,
    });

    return Loan.fromJson(data as Map<String, dynamic>);
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
        .map(
          (rows) => rows
              .where(
                (row) =>
                    row['borrower_id'] == userId || row['lender_id'] == userId,
              )
              .map((row) => Loan.fromJson(row))
              .toList(),
        );
  }
}
