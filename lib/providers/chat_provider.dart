import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/chat_read.dart';
import 'service_providers.dart';

// ── Streams ────────────────────────────────────────────────────────────────────

final globalMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.watch(chatServiceProvider).watchGlobalMessages();
});

final classMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, classId) {
  return ref.watch(chatServiceProvider).watchClassMessages(classId);
});

final chatReadsProvider = StreamProvider<List<ChatRead>>((ref) {
  return ref.watch(chatServiceProvider).watchReads();
});

final chatReadsMapProvider = Provider<Map<String, List<ChatRead>>>((ref) {
  final reads = ref.watch(chatReadsProvider).valueOrNull ?? [];
  final map = <String, List<ChatRead>>{};
  for (final read in reads) {
    if (read.lastReadMessageId != null) {
      map.putIfAbsent(read.lastReadMessageId!, () => []).add(read);
    }
  }
  return map;
});

// ── State ──────────────────────────────────────────────────────────────────────

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

  // ── Global chat ──────────────────────────────────────────────────────────────

  Future<ChatSendResult?> sendGlobalMessage(String content) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result =
          await _ref.read(chatServiceProvider).sendGlobalMessage(content);
      state = state.copyWith(isSending: false);
      return result;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSending: false, error: msg);
      return null;
    }
  }

  Future<ChatSendResult?> sendLoanRequestChat(
    double amount, {
    double? interestRate,
    DateTime? dueDate,
    String? note,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _ref.read(chatServiceProvider).sendLoanRequestChat(
            amount,
            interestRate: interestRate,
            dueDate: dueDate,
            note: note,
          );
      state = state.copyWith(isSending: false);
      return result;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSending: false, error: msg);
      return null;
    }
  }

  // ── Class chat ───────────────────────────────────────────────────────────────

  Future<ChatSendResult?> sendClassMessage(
    String classId,
    String content,
  ) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _ref
          .read(chatServiceProvider)
          .sendClassMessage(classId, content);
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

  Future<ChatSendResult?> editClassMessage(
    String messageId,
    String content,
  ) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _ref
          .read(chatServiceProvider)
          .editClassMessage(messageId, content);
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

  // ── Shared ───────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId) async {
    await _ref.read(chatServiceProvider).deleteMessage(messageId);
  }

  Future<void> adminDeleteMessage(String messageId) async {
    await _ref.read(chatServiceProvider).adminDeleteMessage(messageId);
  }

  Future<void> markRead(String messageId) async {
    await _ref.read(chatServiceProvider).markChatRead(messageId);
  }

  void clearMuteIfExpired() {
    if (state.mutedUntil != null &&
        state.mutedUntil!.isBefore(DateTime.now())) {
      state = state.copyWith(clearMute: true, warningCount: 0);
    }
  }
}
