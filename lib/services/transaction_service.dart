import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/transaction.dart';

class TransactionService {
  final SupabaseClient _client;

  TransactionService(this._client);

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  /// Historique paginé d'un utilisateur (crédits + débits)
  Future<List<Transaction>> getTransactions({
    required String userId,
    int page = 0,
    int pageSize = AppConstants.transactionHistoryPageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final data = await _client
        .from(AppConstants.tableTransactions)
        .select('''
          *,
          from_profile:profiles!from_user_id(username, display_name, avatar_url),
          to_profile:profiles!to_user_id(username, display_name, avatar_url)
        ''')
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .range(from, to);

    return (data as List)
        .where((e) => !_shouldHideAuctionSettlement(userId, e as Map<String, dynamic>))
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Dernières N transactions pour le dashboard
  Future<List<Transaction>> getRecentTransactions({
    required String userId,
    int limit = 5,
  }) async {
    final data = await _client
        .from(AppConstants.tableTransactions)
        .select('''
          *,
          from_profile:profiles!from_user_id(username, display_name, avatar_url),
          to_profile:profiles!to_user_id(username, display_name, avatar_url)
        ''')
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .where((e) => !_shouldHideAuctionSettlement(userId, e as Map<String, dynamic>))
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Récupère une transaction par son ID
  Future<Transaction> getTransaction(String transactionId) async {
    final data = await _client.from(AppConstants.tableTransactions).select('''
          *,
          from_profile:profiles!from_user_id(username, display_name, avatar_url),
          to_profile:profiles!to_user_id(username, display_name, avatar_url)
        ''').eq('id', transactionId).single();

    return Transaction.fromJson(data);
  }

  // ─── Transfert ───────────────────────────────────────────────────────────────

  /// Envoie des SES Coins à un autre utilisateur (par ID)
  /// Passe par une RPC pour garantir l'atomicité (débit + crédit + notif)
  Future<Transaction> transfer({
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? description,
  }) async {
    if (amount < AppConstants.minTransferAmount) {
      throw Exception(
          'Montant minimum : ${AppConstants.minTransferAmount} ${AppConstants.currencySymbol}');
    }
    if (amount > AppConstants.maxTransferAmount) {
      throw Exception(
          'Montant maximum : ${AppConstants.maxTransferAmount} ${AppConstants.currencySymbol}');
    }
    if (fromUserId == toUserId) {
      throw Exception('Impossible de s\'envoyer des fonds à soi-même.');
    }

    final response = await _client.rpc('transfer_funds', params: {
      'p_from_user_id': fromUserId,
      'p_to_user_id': toUserId,
      'p_amount': amount,
      'p_description': description,
      'p_type': TransactionType.transfer.dbValue,
    });

    return Transaction.fromJson(response as Map<String, dynamic>);
  }

  /// Transfert par username (résout l'ID puis appelle [transfer])
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

  // ─── Paiement NFC / QR ───────────────────────────────────────────────────────

  /// Initie une demande de paiement en face-à-face.
  /// Le destinataire crée la demande, le payeur la confirme.
  Future<String> createPaymentRequest({
    required String recipientId,
    required double amount,
    String? description,
  }) async {
    final response = await _client.rpc('create_payment_request', params: {
      'p_recipient_id': recipientId,
      'p_amount': amount,
      'p_description': description,
    });
    // Retourne le token de la demande (UUID) à encoder dans le QR / NFC
    return response as String;
  }

  /// Le payeur confirme la transaction après scan NFC/QR
  Future<Transaction> confirmPaymentRequest({
    required String payerId,
    required String paymentToken,
  }) async {
    final response = await _client.rpc('confirm_payment_request', params: {
      'p_payer_id': payerId,
      'p_payment_token': paymentToken,
    });

    return Transaction.fromJson(response as Map<String, dynamic>);
  }

  /// Le destinataire confirme la réception (étape finale côté receveur)
  Future<void> acknowledgePayment({
    required String recipientId,
    required String transactionId,
  }) async {
    await _client.rpc('acknowledge_payment', params: {
      'p_recipient_id': recipientId,
      'p_transaction_id': transactionId,
    });
  }

  // ─── Realtime ────────────────────────────────────────────────────────────────

  /// Stream des nouvelles transactions d'un utilisateur
  Stream<List<Transaction>> watchRecentTransactions(String userId) {
    return _client
        .from(AppConstants.tableTransactions)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          return rows
              .where((r) =>
                  r['from_user_id'] == userId || r['to_user_id'] == userId)
              .where((r) => !_shouldHideAuctionSettlement(userId, r))
              .take(AppConstants.transactionHistoryPageSize)
              .map((r) => Transaction.fromJson(r))
              .toList();
        });
  }

  bool _shouldHideAuctionSettlement(
    String userId,
    Map<String, dynamic> row,
  ) {
    final metadata = row['metadata'] as Map<String, dynamic>?;
    return row['type'] == 'auction' &&
        row['from_user_id'] == userId &&
        metadata?['auction_id'] != null;
  }
}
