import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/features/feed/models/product.dart';

/// Provider exposing the single instance of ChatService.
final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService();
  ref.onDispose(() => service.dispose());
  return service;
});

final chatMessagesStreamProvider = StreamProvider.family<List<Message>, String>((ref, roomId) async* {
  final service = ref.watch(chatServiceProvider);
  yield service.activeMessages;
  yield* service.watchMessages(roomId);
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
  }) async {
    state = const AsyncValue.loading();
    try {
      await _chatService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        roomId: roomId,
        product: product,
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
