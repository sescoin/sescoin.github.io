import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

class ChatService {
  ChatService(this._client);

  final SupabaseClient _client;

  Stream<List<ChatMessage>> watchMessages() {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .limit(100)
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  Future<ChatSendResult> sendMessage(String content) async {
    final response = await _client.rpc(
      'send_chat_message',
      params: {'p_content': content},
    );
    return ChatSendResult.fromJson(response as Map<String, dynamic>);
  }
}
