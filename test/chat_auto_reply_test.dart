import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: Secure Chat Auto-Reply & RPC Integration', () {
    late ChatService chatService;

    setUp(() {
      chatService = ChatService();
    });

    tearDown(() {
      chatService.dispose();
    });

    test('Initializes with default active messages', () {
      expect(chatService.activeMessages.length, greaterThanOrEqualTo(2));
      final firstMsg = chatService.activeMessages.first;
      expect(firstMsg.roomId, equals('room-demo'));
    });

    test('Filters messages for specific room correctly', () {
      final demoMessages = chatService.getMessagesForRoom('room-demo');
      expect(demoMessages.isNotEmpty, isTrue);
      for (final msg in demoMessages) {
        expect(msg.roomId, equals('room-demo'));
      }

      final emptyMessages = chatService.getMessagesForRoom('non-existent-room');
      expect(emptyMessages.isEmpty, isTrue);
    });

    test('Message model JSON serialization integrity', () {
      final msg = Message(
        id: 'msg-test-123',
        senderId: 'buyer-uuid',
        receiverId: 'seller-uuid',
        content: 'Is this uniform still available?',
        createdAt: DateTime(2026, 9, 30, 10, 0),
        roomId: 'room-test',
      );

      final jsonMap = msg.toJson();
      expect(jsonMap['id'], 'msg-test-123');
      expect(jsonMap['sender_id'], 'buyer-uuid');
      expect(jsonMap['content'], 'Is this uniform still available?');

      final reconstructed = Message.fromJson({
        'id': 'msg-test-123',
        'sender_id': 'buyer-uuid',
        'receiver_id': 'seller-uuid',
        'content': 'Is this uniform still available?',
        'room_id': 'room-test',
        'created_at': DateTime(2026, 9, 30, 10, 0).toIso8601String(),
      });
      expect(reconstructed.id, msg.id);
      expect(reconstructed.senderId, msg.senderId);
      expect(reconstructed.content, msg.content);
      expect(reconstructed.roomId, msg.roomId);
    });

    test('Demo auto-reply generates appropriate seller responses', () async {
      final product = Product(
        id: 'prod-test-1',
        title: 'CIT Engineering Uniform Medium',
        description: 'Clean preloved uniform',
        price: 350.0,
        imageUrl: 'https://example.com/uniform.jpg',
        sellerId: 'demo-seller',
        condition: 'Good',
        category: 'Uniforms',
        createdAt: DateTime.now(),
      );

      // Send inquiry about price/availability in demo room
      await chatService.sendMessage(
        senderId: 'buyer-uuid',
        receiverId: 'demo-seller',
        content: 'Is this available?',
        roomId: 'room-demo',
        product: product,
      );

      // Verify buyer's message is immediately added
      final messages = chatService.getMessagesForRoom('room-demo');
      expect(messages.any((m) => m.content == 'Is this available?' && m.senderId == 'buyer-uuid'), isTrue);

      // Wait for the 2-second assistant auto-reply simulation
      await Future.delayed(const Duration(milliseconds: 2200));

      final updatedMessages = chatService.getMessagesForRoom('room-demo');
      expect(
        updatedMessages.any((m) => m.senderId == 'demo-seller' && m.content.contains('is available')),
        isTrue,
      );
    });
  });
}
