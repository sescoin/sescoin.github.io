import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'service_providers.dart';

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.watch(chatServiceProvider).watchMessages();
});

class ChatState {
  const ChatState({
    this.isSending = false,
    this.error,
    this.warningCount = 0,
    this.mutedUntil,
  });

  final bool isSending;
  final String? error;
  final int warningCount;
  final DateTime? mutedUntil;

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  ChatState copyWith({
    bool? isSending,
    String? error,
    int? warningCount,
    DateTime? mutedUntil,
    bool clearError = false,
    bool clearMute = false,
  }) {
    return ChatState(
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      warningCount: warningCount ?? this.warningCount,
      mutedUntil: clearMute ? null : (mutedUntil ?? this.mutedUntil),
    );
  }
}

final chatActionProvider =
    StateNotifierProvider<ChatActionNotifier, ChatState>((ref) {
  return ChatActionNotifier(ref);
});

class ChatActionNotifier extends StateNotifier<ChatState> {
  ChatActionNotifier(this._ref) : super(const ChatState());

  final Ref _ref;

  Future<ChatSendResult?> sendMessage(String content) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _ref.read(chatServiceProvider).sendMessage(content);
      state = state.copyWith(
        isSending: false,
        warningCount: result.warningCount,
        mutedUntil: result.muted
            ? DateTime.now().add(const Duration(minutes: 10))
            : null,
        clearMute: !result.muted,
      );
      return result;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSending: false, error: msg);
      return null;
    }
  }

  void clearMuteIfExpired() {
    if (state.mutedUntil != null &&
        state.mutedUntil!.isBefore(DateTime.now())) {
      state = state.copyWith(clearMute: true, warningCount: 0);
    }
  }
}
