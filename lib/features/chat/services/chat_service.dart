import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/chat/models/message.dart';

/// Real-time chat service using Supabase Realtime channels.
/// Listens to the `messages` table for INSERT events on the given chat room.
class ChatService {
  SupabaseClient get _client => SupabaseConfig.client;

  // Local broadcast stream for UI reactivity
  final _messageController = StreamController<List<Message>>.broadcast();
  final List<Message> _activeMessages = [];
  RealtimeChannel? _channel;

  List<Message> get activeMessages => List.unmodifiable(_activeMessages);

  // ── Initialize with seed messages for demo ──
  ChatService() {
    _seedDemoMessages();
  }

  void _seedDemoMessages() {
    _activeMessages.addAll([
      Message(
        id: 'msg-seed-1',
        senderId: 'demo-seller',
        receiverId: 'demo-buyer',
        content:
            'Hi! Let me know if you are interested in the engineering drawing table.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        roomId: 'room-demo',
      ),
      Message(
        id: 'msg-seed-2',
        senderId: 'demo-buyer',
        receiverId: 'demo-seller',
        content:
            'Hello! Yes, is the price still negotiable? Can we do ₱400 instead of ₱450?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        roomId: 'room-demo',
      ),
    ]);
    _messageController.add(List.from(_activeMessages));
  }

  /// Finds or creates a real Chat Room in the Supabase database.
  /// Seamlessly chains the creation of inquiries and variant SKUs to satisfy FK checks.
  Future<String> getOrCreateChatRoom({
    required String buyerId,
    required String sellerId,
    required String productId,
  }) async {
    try {
      final buyerCheck = await _client.from('users').select('user_id').eq('user_id', buyerId).limit(1).maybeSingle();
      if (buyerCheck == null) {
        await _client.from('users').insert({
          'user_id': buyerId,
          'full_name': 'Wildcat Buyer',
          'email': 'buyer.${buyerId.substring(0, 5)}@cit.edu',
          'password_hash': 'pbkdf2_sha256\$260000\$dummyhashbuyer',
          'role': 'BUYER',
          'is_verified': true,
        });
      }

      // Ensure seller exists in users table (violates chats_seller_id_fkey otherwise)
      final sellerCheck = await _client.from('users').select('user_id').eq('user_id', sellerId).limit(1).maybeSingle();
      if (sellerCheck == null) {
        await _client.from('users').insert({
          'user_id': sellerId,
          'full_name': 'Wildcat Seller',
          'email': 'seller.${sellerId.substring(0, 5)}@cit.edu',
          'password_hash': 'pbkdf2_sha256\$260000\$dummyhashseller',
          'role': 'SELLER',
          'is_verified': true,
        });
      }

      // 2. Try to find an existing chat room for this buyer and seller
      final existingChat = await _client
          .from('chats')
          .select('chat_id')
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .limit(1)
          .maybeSingle();

      if (existingChat != null) {
        return existingChat['chat_id'] as String;
      }

      // 3. We need an inquiry first. Find or create one.
      // Check for an existing product variant
      final productVariants = await _client
          .from('product_variants')
          .select('variant_id')
          .eq('product_id', productId)
          .limit(1);

      String variantId;
      if (productVariants != null && (productVariants as List).isNotEmpty) {
        variantId = productVariants[0]['variant_id'] as String;
      } else {
        // Create a dummy variant if none exists (fallback)
        final newVariant = await _client.from('product_variants').insert({
          'product_id': productId,
          'variant_name': 'Standard',
          'variant_value': 'Default',
          'sku': 'SKU-${productId.substring(0, 8).toUpperCase()}-DEFAULT',
        }).select().single();
        variantId = newVariant['variant_id'] as String;
        
        // Also seed the corresponding inventory entry
        await _client.from('inventory').insert({
          'variant_id': variantId,
          'stock_qty': 10,
          'reserved_qty': 0,
        });
      }

      final existingInquiry = await _client
          .from('inquiries')
          .select('inquiry_id')
          .eq('buyer_id', buyerId)
          .eq('product_id', productId)
          .limit(1)
          .maybeSingle();

      String inquiryId;
      if (existingInquiry != null) {
        inquiryId = existingInquiry['inquiry_id'] as String;
      } else {
        final newInquiry = await _client.from('inquiries').insert({
          'buyer_id': buyerId,
          'product_id': productId,
          'variant_id': variantId,
          'quantity': 1,
          'inquiry_type': 'AVAILABILITY',
          'message': 'Hi, I would like to inquire about this product.',
        }).select().single();
        inquiryId = newInquiry['inquiry_id'] as String;
      }

      // 4. Create the chat room linking to this inquiry
      final newChat = await _client.from('chats').insert({
        'inquiry_id': inquiryId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
      }).select().single();

      return newChat['chat_id'] as String;
    } catch (e) {
      print("GET_OR_CREATE_CHAT_ROOM_ERROR: $e");
      // Rethrow so the exact database constraint error pops up directly in the UI SnackBar!
      rethrow;
    }
  }


  /// Watch messages for a given Supabase chat_id (room).
  /// Falls back to the local broadcast stream for demo rooms.
  Stream<List<Message>> watchMessages(String roomId) async* {
    if (roomId != 'room-demo' && !roomId.startsWith('demo-')) {
      // 1. Fetch initial messages synchronously within the stream subscription
      try {
        final response = await _client
            .from('messages')
            .select('*')
            .eq('chat_id', roomId)
            .order('sent_at', ascending: true);

        final rows = response as List<dynamic>;
        final loaded = rows.map((row) => Message(
              id: row['message_id'] as String,
              senderId: row['sender_id'] as String,
              receiverId: '', // not stored in messages, derive from chat
              content: row['content'] as String? ?? '',
              createdAt: DateTime.tryParse(row['sent_at'] as String? ?? '') ??
                  DateTime.now(),
              roomId: roomId,
              imageUrl: row['image_url'] as String?,
            )).toList();

        _activeMessages.clear();
        _activeMessages.addAll(loaded);
      } catch (e, stackTrace) {
        print("SUBSCRIBE_ROOM_READ_ERROR for room $roomId: $e");
        print(stackTrace);
        // Throwing here correctly propagates the error state to Riverpod and UI
        throw e;
      }

      // Now yield the loaded database messages immediately
      yield List.from(_activeMessages);

      // 2. Setup real-time listener asynchronously
      _subscribeToRealtime(roomId);
    } else {
      // Yield initial demo/memory messages
      yield List.from(_activeMessages);
    }

    // Yield any subsequent updates added to the shared broadcast controller
    yield* _messageController.stream;
  }

  Future<void> _subscribeToRealtime(String chatId) async {
    // Unsubscribe from previous channel to avoid duplicates
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }

    _channel = _client
        .channel('chat:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRow = payload.newRecord;
            final msgRoomId = newRow['chat_id'] as String?;
            if (msgRoomId != chatId) return; // Ignore messages for other rooms

            final msg = Message(
              id: newRow['message_id'] as String,
              senderId: newRow['sender_id'] as String,
              receiverId: '',
              content: newRow['content'] as String? ?? '',
              createdAt:
                  DateTime.tryParse(newRow['sent_at'] as String? ?? '') ??
                      DateTime.now(),
              roomId: chatId,
              imageUrl: newRow['image_url'] as String?,
            );
            
            // Check if this message is already tracked (or exists locally as an optimistic send)
            final exists = _activeMessages.any((m) => 
              m.id == msg.id || 
              (m.senderId == msg.senderId && m.content == msg.content && m.id.startsWith('msg-'))
            );
            
            if (!exists) {
              _activeMessages.add(msg);
              _messageController.add(List.from(_activeMessages));
            } else {
              // Update the optimistic temporary message with the actual database UUID and timestamp
              final index = _activeMessages.indexWhere((m) => 
                m.senderId == msg.senderId && m.content == msg.content && m.id.startsWith('msg-')
              );
              if (index != -1) {
                _activeMessages[index] = msg;
                _messageController.add(List.from(_activeMessages));
              }
            }
          },
        );
        
    _channel!.subscribe((status, [error]) {
      print("REALTIME_SUBSCRIPTION_STATUS for $chatId: $status, error: $error");
    });
  }

  /// Sends a message. For live chat rooms, inserts into Supabase messages table.
  /// For demo rooms, simulates a negotiation reply.
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required String roomId,
    String? imageUrl,
  }) async {
    final userMessage = Message(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      createdAt: DateTime.now(),
      roomId: roomId,
      imageUrl: imageUrl,
    );

    _activeMessages.add(userMessage);
    _messageController.add(List.from(_activeMessages));

    // Persist to Supabase for live rooms
    if (roomId != 'room-demo' && !roomId.startsWith('demo-')) {
      try {
        await _client.from('messages').insert({
          'chat_id': roomId,
          'sender_id': senderId,
          'content': content,
          'image_url': imageUrl,
          'is_read': false,
        });
      } catch (e, stackTrace) {
        _activeMessages.remove(userMessage);
        _messageController.add(List.from(_activeMessages));
        print("SEND_MESSAGE_INSERT_ERROR: $e");
        print(stackTrace);
        rethrow;
      }
      return;
    }

    // Demo negotiation auto-reply simulation
    if (content.contains('₱400') ||
        content.toLowerCase().contains('deal') ||
        content.toLowerCase().contains('₱')) {
      Future.delayed(const Duration(seconds: 2), () {
        final sellerReply = Message(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}-reply',
          senderId: receiverId,
          receiverId: senderId,
          content:
              'Sure! I can accept ₱400. Let\'s meet at the Library Lobby for the item exchange. Deal! 🤝',
          createdAt: DateTime.now(),
          roomId: roomId,
        );
        _activeMessages.add(sellerReply);
        _messageController.add(List.from(_activeMessages));
      });
    }
  }

  void dispose() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _messageController.close();
  }
}
