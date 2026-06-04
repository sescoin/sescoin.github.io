import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/chat_read.dart';

class ChatService {
  ChatService(this._client);

  final SupabaseClient _client;

  Stream<List<ChatMessage>> watchMessages() {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows
            .map(ChatMessage.fromJson)
            .where((m) => !m.isExpired && !m.isDeleted)
            .toList());
  }

  Stream<List<ChatRead>> watchReads() {
    return _client
        .from('chat_reads')
        .stream(primaryKey: ['user_id'])
        .map((rows) => rows.map(ChatRead.fromJson).toList());
  }

  Future<ChatSendResult> sendMessage(String content) async {
    final response = await _client.rpc(
      'send_chat_message',
      params: {'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }

  Future<void> editMessage(String messageId, String content) async {
    await _client.rpc(
      'edit_chat_message',
      params: {'p_message_id': messageId, 'p_content': content},
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.rpc(
      'delete_chat_message',
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
