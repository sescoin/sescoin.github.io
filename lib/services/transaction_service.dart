import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/transaction.dart';

class TransactionService {
  TransactionService(this._client);

  final SupabaseClient _client;

  static const _transactionSelect = '''
    *,
    from_profile:profiles!from_user_id(username, display_name, avatar_url),
    to_profile:profiles!to_user_id(username, display_name, avatar_url)
  ''';

  Future<List<Transaction>> getTransactions({
    required String userId,
    int page = 0,
    int pageSize = AppConstants.transactionHistoryPageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final data = await _client
        .from(AppConstants.tableTransactions)
        .select(_transactionSelect)
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List)
        .where(
          (row) => !_shouldHideAuctionSettlement(userId, row as Map<String, dynamic>),
        )
        .map((row) => Transaction.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Transaction>> getRecentTransactions({
    required String userId,
    int limit = 5,
  }) async {
    final data = await _client
        .from(AppConstants.tableTransactions)
        .select(_transactionSelect)
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .where(
          (row) => !_shouldHideAuctionSettlement(userId, row as Map<String, dynamic>),
        )
        .map((row) => Transaction.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> getTransaction(String transactionId) async {
    final data = await _client
        .from(AppConstants.tableTransactions)
        .select(_transactionSelect)
        .eq('id', transactionId)
        .single();

    return Transaction.fromJson(data);
  }

  Future<List<Transaction>> getGlobalTransactions({
    int limit = 100,
  }) async {
    final data = await _client
        .from(AppConstants.tableTransactions)
        .select(_transactionSelect)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((row) => Transaction.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> transfer({
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? description,
  }) async {
    if (amount < AppConstants.minTransferAmount) {
      throw Exception(
        'Montant minimum : ${AppConstants.minTransferAmount} ${AppConstants.currencySymbol}',
      );
    }
    if (amount > AppConstants.maxTransferAmount) {
      throw Exception(
        'Montant maximum : ${AppConstants.maxTransferAmount} ${AppConstants.currencySymbol}',
      );
    }
    if (fromUserId == toUserId) {
      throw Exception('Impossible de s\'envoyer des fonds à soi-même.');
    }

    final data = await _client.rpc('transfer_funds', params: {
      'p_from_user_id': fromUserId,
      'p_to_user_id': toUserId,
      'p_amount': amount,
      'p_description': description,
      'p_type': TransactionType.transfer.dbValue,
    });

    return Transaction.fromJson(data as Map<String, dynamic>);
  }

  Future<Transaction> transferByUsername({
    required String fromUserId,
    required String toUsername,
    required double amount,
    String? description,
  }) async {
    final profileData = await _client
        .from(AppConstants.tableProfiles)
        .select('id')
        .eq('username', toUsername)
        .eq('is_banned', false)
        .maybeSingle();

    if (profileData == null) {
      throw Exception('Aucun compte actif trouvé pour "$toUsername".');
    }

    return transfer(
      fromUserId: fromUserId,
      toUserId: profileData['id'] as String,
      amount: amount,
      description: description,
    );
  }

  Future<String> createPaymentRequest({
    required String recipientId,
    required double amount,
    String? description,
  }) async {
    final data = await _client.rpc('create_payment_request', params: {
      'p_recipient_id': recipientId,
      'p_amount': amount,
      'p_description': description,
    });

    return data as String;
  }

  Future<Transaction> confirmPaymentRequest({
    required String payerId,
    required String paymentToken,
  }) async {
    final data = await _client.rpc('confirm_payment_request', params: {
      'p_payer_id': payerId,
      'p_payment_token': paymentToken,
    });

    return Transaction.fromJson(data as Map<String, dynamic>);
  }

  Future<void> acknowledgePayment({
    required String recipientId,
    required String transactionId,
  }) async {
    await _client.rpc('acknowledge_payment', params: {
      'p_recipient_id': recipientId,
      'p_transaction_id': transactionId,
    });
  }

  Stream<List<Transaction>> watchRecentTransactions(String userId) {
    return _client
        .from(AppConstants.tableTransactions)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    row['from_user_id'] == userId || row['to_user_id'] == userId,
              )
              .where((row) => !_shouldHideAuctionSettlement(userId, row))
              .take(AppConstants.transactionHistoryPageSize)
              .map((row) => Transaction.fromJson(row))
              .toList(),
        );
  }

  Stream<List<Transaction>> watchGlobalTransactions({int limit = 120}) {
    return _client
        .from(AppConstants.tableTransactions)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap(
          (rows) async => _hydrateTransactions(rows.take(limit).toList()),
        );
  }

  Future<List<Transaction>> _hydrateTransactions(
    List<Map<String, dynamic>> rows,
  ) async {
    final userIds = <String>{};
    for (final row in rows) {
      final fromUserId = row['from_user_id'] as String?;
      final toUserId = row['to_user_id'] as String?;
      if (fromUserId != null) {
        userIds.add(fromUserId);
      }
      if (toUserId != null) {
        userIds.add(toUserId);
      }
    }

    final profilesById = await _loadProfilesByIds(userIds);

    return rows.map((row) {
      final hydrated = Map<String, dynamic>.from(row);
      final fromProfile = profilesById[row['from_user_id']] ?? const {};
      final toProfile = profilesById[row['to_user_id']] ?? const {};
      hydrated['from_username'] = fromProfile['username'];
      hydrated['to_username'] = toProfile['username'];
      hydrated['from_display_name'] = fromProfile['display_name'];
      hydrated['to_display_name'] = toProfile['display_name'];
      return Transaction.fromJson(hydrated);
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfilesByIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const {};
    }

    final data = await _client
        .from(AppConstants.tableProfiles)
        .select('id, username, display_name')
        .inFilter('id', ids.toList());

    final result = <String, Map<String, dynamic>>{};
    for (final row in data as List) {
      final map = row as Map<String, dynamic>;
      result[map['id'] as String] = map;
    }
    return result;
  }

  bool _shouldHideAuctionSettlement(
    String userId,
    Map<String, dynamic> row,
  ) {
    return false;
  }
}
