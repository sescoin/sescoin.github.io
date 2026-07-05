import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/chat_read.dart';

class ChatService {
  ChatService(this._client);

  final SupabaseClient _client;

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<ChatMessage>> watchGlobalMessages() {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows
            .map(ChatMessage.fromJson)
            .where((m) => m.classId == null && !m.isDeleted && !m.isExpired)
            .toList());
  }

  Stream<List<ChatMessage>> watchClassMessages(String classId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows
            .map(ChatMessage.fromJson)
            .where((m) =>
                m.classId == classId && !m.isDeleted && !m.isExpired)
            .toList());
  }

  Stream<List<ChatRead>> watchReads() {
    return _client.from('chat_reads').stream(primaryKey: ['user_id']).map(
        (rows) => rows.map(ChatRead.fromJson).toList());
  }

  // ── Global chat ────────────────────────────────────────────────────────────

  Future<ChatSendResult> sendGlobalMessage(String content) async {
    try {
      final response = await _client.rpc(
        'send_global_message',
        params: {'p_content': content},
      );
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<ChatSendResult> sendLoanRequestChat(
    double amount, {
    double? interestRate,
    DateTime? dueDate,
    String? note,
    String? classId,
  }) async {
    final params = <String, dynamic>{'p_amount': amount};
    if (interestRate != null) params['p_interest_rate'] = interestRate;
    if (dueDate != null) {
      params['p_due_date'] = dueDate.toUtc().toIso8601String();
    }
    if (note != null) params['p_note'] = note;
    if (classId != null) params['p_class_id'] = classId;
    try {
      final response =
          await _client.rpc('send_loan_request_chat', params: params);
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Cadeaux ────────────────────────────────────────────────────────────────

  /// Envoie un cadeau dans le chat (Annonces si [classId] est null,
  /// chat de classe sinon). Le premier utilisateur qui le récupère l'empoche.
  Future<ChatSendResult> sendChatGift(
    double amount, {
    String? note,
    String? classId,
  }) async {
    final params = <String, dynamic>{'p_amount': amount};
    if (note != null) params['p_note'] = note;
    if (classId != null) params['p_class_id'] = classId;
    try {
      final response = await _client.rpc('send_chat_gift', params: params);
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Tente de récupérer un cadeau — premier arrivé, premier servi
  /// (l'atomicité est garantie côté SQL).
  Future<double> claimChatGift(String messageId) async {
    try {
      final response = await _client.rpc(
        'claim_chat_gift',
        params: {'p_message_id': messageId},
      );
      final map = response as Map<String, dynamic>;
      return (map['amount'] as num).toDouble();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Class chat ─────────────────────────────────────────────────────────────

  Future<ChatSendResult> sendClassMessage(
    String classId,
    String content,
  ) async {
    try {
      final response = await _client.rpc(
        'send_class_message',
        params: {'p_class_id': classId, 'p_content': content},
      );
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<ChatSendResult> editClassMessage(
    String messageId,
    String content,
  ) async {
    try {
      final response = await _client.rpc(
        'edit_class_message',
        params: {'p_message_id': messageId, 'p_content': content},
      );
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ── Shared (own messages) ──────────────────────────────────────────────────

  Future<ChatSendResult> editMessage(String messageId, String content) async {
    try {
      final response = await _client.rpc(
        'edit_chat_message',
        params: {'p_message_id': messageId, 'p_content': content},
      );
      return ChatSendResult.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _client.rpc(
        'delete_chat_message',
        params: {'p_message_id': messageId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> adminDeleteMessage(String messageId) async {
    try {
      await _client.rpc(
        'admin_delete_message',
        params: {'p_message_id': messageId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> acceptChatLoanRequest(String messageId) async {
    try {
      await _client.rpc(
        'accept_chat_loan_request',
        params: {'p_message_id': messageId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markChatRead(String messageId) async {
    await _client.rpc(
      'mark_chat_read',
      params: {'p_message_id': messageId},
    );
  }
}
