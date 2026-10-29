import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/core/models/product.dart';

/// Provider exposing the single instance of ChatService.
final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService();
  ref.onDispose(() => service.dispose());
  return service;
});

final chatMessagesStreamProvider = StreamProvider.autoDispose.family<List<Message>, String>((ref, roomId) {
  final service = ref.read(chatServiceProvider);
  return service.watchMessages(roomId);
});

/// Action notifier to handle sending messages.
class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatService _chatService;

  ChatController(this._chatService) : super(const AsyncValue.data(null));

  Future<void> postMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required String roomId,
    Product? product,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _chatService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        roomId: roomId,
        product: product,
        imageUrl: imageUrl,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatController(service);
});

/// Reactive notifier tracking unread messages for the current user across all chats.
class UnreadChatCountNotifier extends StateNotifier<int> {
  final SupabaseClient _client;
  final String? _userId;
  RealtimeChannel? _channel;

  UnreadChatCountNotifier(this._client, this._userId, {bool autoInit = true}) : super(0) {
    if (autoInit && _userId != null && _userId.isNotEmpty) {
      fetchExactCount();
      _subscribeRealtime();
    }
  }

  void handleIncomingMessage(Map<String, dynamic> record) {
    final senderId = record['sender_id'] as String?;
    final isRead = record['is_read'] as bool? ?? false;
    if (senderId != null && senderId != _userId && !isRead) {
      increment();
    }
  }

  Future<void> fetchExactCount() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final response = await _client
          .from('messages')
          .select('message_id')
          .neq('sender_id', uid)
          .eq('is_read', false)
          .count(CountOption.exact);
      if (mounted) {
        state = response.count;
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;

    _channel?.unsubscribe();
    _channel = _client
        .channel('public:unread_messages:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            handleIncomingMessage(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            fetchExactCount();
          },
        )
        .subscribe();
  }

  void increment() => state = state + 1;
  void decrement() => state = state > 0 ? state - 1 : 0;
  void reset() => state = 0;
  void refresh() => fetchExactCount();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

/// Provider for unread chat count notifier
final unreadChatCountNotifierProvider =
    StateNotifierProvider<UnreadChatCountNotifier, int>((ref) {
  final profile = ref.watch(authStateProvider).valueOrNull;
  return UnreadChatCountNotifier(SupabaseConfig.client, profile?.id);
});

/// Public reactive unread message count provider
final unreadChatCountProvider = Provider<int>((ref) {
  return ref.watch(unreadChatCountNotifierProvider);
});

