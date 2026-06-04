import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/features/feed/models/product.dart';

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

      // 2. We need an inquiry first. Find or create one.
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

      // 3. Try to find an existing chat room for this buyer and seller
      final existingChat = await _client
          .from('chats')
          .select('chat_id')
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .limit(1)
          .maybeSingle();

      if (existingChat != null) {
        final chatId = existingChat['chat_id'] as String;
        
        // Update the existing chat's inquiry_id to the new product inquiry
        // and reset soft-deletion states so that both parties are active!
        await _client.from('chats').update({
          'inquiry_id': inquiryId,
          'deleted_by_buyer': false,
          'deleted_by_seller': false,
        }).eq('chat_id', chatId);
        
        return chatId;
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
        final currentUser = _client.auth.currentUser;
        String? clearedAt;
        if (currentUser != null) {
          final roomData = await _client
              .from('chats')
              .select('buyer_id, seller_id, buyer_cleared_at, seller_cleared_at')
              .eq('chat_id', roomId)
              .maybeSingle();
          if (roomData != null) {
            final isBuyer = currentUser.id == roomData['buyer_id'];
            clearedAt = isBuyer
                ? roomData['buyer_cleared_at'] as String?
                : roomData['seller_cleared_at'] as String?;
            print("WATCH_MESSAGES_DEBUG: roomId=$roomId, userId=${currentUser.id}, isBuyer=$isBuyer, clearedAt=$clearedAt");
          } else {
            print("WATCH_MESSAGES_DEBUG: Room data not found for roomId=$roomId");
          }
        } else {
          print("WATCH_MESSAGES_DEBUG: Current authenticated user is NULL");
        }

        var dbQuery = _client.from('messages').select('*').eq('chat_id', roomId);
        if (clearedAt != null) {
          dbQuery = dbQuery.gt('sent_at', clearedAt);
        }

        final response = await dbQuery.order('sent_at', ascending: true);
        print("WATCH_MESSAGES_DEBUG: Fetched ${response.length} messages after filtering");

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

  /// Sends a message. For live chat rooms, inserts into Supabase messages table
  /// and triggers an automated assistant reply as the seller.
  /// For demo rooms, simulates an automated assistant response locally.
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required String roomId,
    String? imageUrl,
    Product? product,
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

        // Trigger live auto-reply for live rooms
        if (senderId != receiverId && product != null) {
          final responseText = _getAssistantResponse(content, product);
          if (responseText != null) {
            Future.delayed(const Duration(seconds: 2), () async {
              try {
                await _client.from('messages').insert({
                  'chat_id': roomId,
                  'sender_id': receiverId, // Sent as the seller
                  'content': responseText,
                  'image_url': null,
                  'is_read': false,
                });
              } catch (e) {
                print("LIVE_AUTO_REPLY_ERROR: $e");
              }
            });
          }
        }
      } catch (e, stackTrace) {
        _activeMessages.remove(userMessage);
        _messageController.add(List.from(_activeMessages));
        print("SEND_MESSAGE_INSERT_ERROR: $e");
        print(stackTrace);
        rethrow;
      }
      return;
    }

    // Demo negotiation auto-reply simulation using the Automated Chat Assistant rules
    // Only trigger if the buyer is the one sending the message (prevent self-reply/loops)
    if (senderId != receiverId && product != null) {
      final responseText = _getAssistantResponse(content, product);
      if (responseText != null) {
        Future.delayed(const Duration(seconds: 2), () {
          final sellerReply = Message(
            id: 'msg-${DateTime.now().millisecondsSinceEpoch}-reply',
            senderId: receiverId,
            receiverId: senderId,
            content: responseText,
            createdAt: DateTime.now(),
            roomId: roomId,
          );
          _activeMessages.add(sellerReply);
          _messageController.add(List.from(_activeMessages));
        });
      }
    }
  }


  /// Generates a context-aware automated assistant response.
  /// Returns null if the message does not match specific inquiries about:
  /// 1. Price
  /// 2. Availability
  /// 3. Meetup Location / Time (When & Where)
  String? _getAssistantResponse(String messageText, Product product, {String? sellerFirstName}) {
    final msg = messageText.toLowerCase().trim();

    // Resolve seller first name: use provided name, fallback to 'Clarence' for demo, else 'the seller'
    final String resolvedSellerName = sellerFirstName ??
        (product.sellerId == 'demo-seller' || product.sellerId.startsWith('demo')
            ? 'Clarence'
            : 'the seller');

    const String responseTime = '10 minutes';
    const String meetupLocation = 'not specified';
    const int stock = 3; // fallback stock for demo/unknown products

    // 1. Price Inquiry
    if (msg.contains('price') || msg.contains('magkano') || msg.contains('how much') || msg.contains('hm') || msg.contains('cost') || msg.contains('peso')) {
      return "The price for the ${product.title} is ₱${product.price.toStringAsFixed(0)}. Do note that this is already the final fixed price!";
    }

    // 2. Availability / Stock Inquiry & Greetings
    if (msg.contains('available') || msg.contains('stock') || msg.contains('meron') || msg.contains('sold') || msg.contains('still there') || msg.contains('avail') ||
        msg.contains('hi') || msg.contains('hello') || msg.contains('hoy') || msg.contains('uy') || msg.contains('interested') || msg.contains('gusto') || msg.contains('inquire')) {
      if (stock > 0) {
        return "Hi! Yes, the ${product.title} is available. Feel free to ask anything!";
      } else {
        return "The ${product.title} is currently out of stock. I'll let $resolvedSellerName know you're looking for it!";
      }
    }

    // 3. Meetup Location / Time Inquiry (When and where is the seller available)
    if (msg.contains('meet') || msg.contains('location') || msg.contains('saan') || msg.contains('place') || msg.contains('spot') || msg.contains('meetup') ||
        msg.contains('when') || msg.contains('free') || msg.contains('oras') || msg.contains('time') || msg.contains('schedule') || msg.contains('day') || msg.contains('pwede') || msg.contains('pede')) {
      if (meetupLocation != 'not specified' && meetupLocation.isNotEmpty) {
        return "For meetups, $resolvedSellerName prefers: $meetupLocation. Let us know if this works for you!";
      } else {
        return "We can meet at common campus spots like the library, canteen, or the guard post. $resolvedSellerName will confirm the exact spot and time with you!";
      }
    }

    // No reply for unrecognized/ambiguous messages
    return null;
  }

  /// Soft deletes/clears a chat room for the current user.
  Future<void> softDeleteChatRoom(String chatId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return;

      final chatRoomRes = await _client
          .from('chats')
          .select('buyer_id, seller_id, deleted_by_buyer, deleted_by_seller')
          .eq('chat_id', chatId)
          .maybeSingle();

      if (chatRoomRes == null) return;

      final isBuyer = currentUser.id == chatRoomRes['buyer_id'];
      final now = DateTime.now().toUtc().toIso8601String();

      if (isBuyer) {
        final sellerDeleted = chatRoomRes['deleted_by_seller'] as bool? ?? false;
        if (sellerDeleted) {
          // If both parties deleted the chat, completely purge the room and its messages
          await _client.from('chats').delete().eq('chat_id', chatId);
        } else {
          await _client.from('chats').update({
            'deleted_by_buyer': true,
            'buyer_cleared_at': now,
          }).eq('chat_id', chatId);
        }
      } else {
        final buyerDeleted = chatRoomRes['deleted_by_buyer'] as bool? ?? false;
        if (buyerDeleted) {
          // If both parties deleted the chat, completely purge the room and its messages
          await _client.from('chats').delete().eq('chat_id', chatId);
        } else {
          await _client.from('chats').update({
            'deleted_by_seller': true,
            'seller_cleared_at': now,
          }).eq('chat_id', chatId);
        }
      }
    } catch (e) {
      print("SOFT_DELETE_CHAT_ROOM_ERROR: $e");
      rethrow;
    }
  }

  void dispose() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _messageController.close();
  }
}
