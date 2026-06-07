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
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows
            .map(ChatMessage.fromJson)
            .where((m) => m.classId == null && !m.isExpired)
            .toList());
  }

  Stream<List<ChatMessage>> watchClassMessages(String classId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows
            .map(ChatMessage.fromJson)
            .where((m) => m.classId == classId && !m.isExpired)
            .toList());
  }

  Stream<List<ChatRead>> watchReads() {
    return _client.from('chat_reads').stream(primaryKey: ['user_id']).map(
        (rows) => rows.map(ChatRead.fromJson).toList());
  }

  // ── Global chat ────────────────────────────────────────────────────────────

  Future<ChatSendResult> sendGlobalMessage(String content) async {
    final response = await _client.rpc(
      'send_global_message',
      params: {'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  Future<ChatSendResult> sendLoanRequestChat(
    double amount, {
    String? note,
  }) async {
    final response = await _client.rpc(
      'send_loan_request_chat',
      params: {'p_amount': amount, 'p_note': note},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  // ── Class chat ─────────────────────────────────────────────────────────────

  Future<ChatSendResult> sendClassMessage(
    String classId,
    String content,
  ) async {
    final response = await _client.rpc(
      'send_class_message',
      params: {'p_class_id': classId, 'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  Future<ChatSendResult> editClassMessage(
    String messageId,
    String content,
  ) async {
    final response = await _client.rpc(
      'edit_class_message',
      params: {'p_message_id': messageId, 'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  // ── Shared (own messages) ──────────────────────────────────────────────────

  Future<ChatSendResult> editMessage(String messageId, String content) async {
    final response = await _client.rpc(
      'edit_chat_message',
      params: {'p_message_id': messageId, 'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.rpc(
      'delete_chat_message',
      params: {'p_message_id': messageId},
    );
  }

  Future<void> adminDeleteMessage(String messageId) async {
    await _client.rpc(
      'admin_delete_message',
      params: {'p_message_id': messageId},
    );
  }

  Future<void> markChatRead(String messageId) async {
    await _client.rpc(
      'mark_chat_read',
      params: {'p_message_id': messageId},
    );
  }
}
