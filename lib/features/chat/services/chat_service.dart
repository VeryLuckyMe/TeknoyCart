import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/core/models/product.dart';

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
  /// Returns messages filtered for a specific room.
  List<Message> getMessagesForRoom(String roomId) {
    return _activeMessages.where((m) => m.roomId == roomId).toList();
  }

  /// Finds or creates a real Chat Room in the Supabase database.
  /// Seamlessly chains the creation of inquiries and variant SKUs to satisfy FK checks.
  Future<String> getOrCreateChatRoom({
    required String buyerId,
    required String sellerId,
    required String productId,
    String? productName,
    double? productPrice,
  }) async {
    try {
      if (buyerId.startsWith('demo-') || sellerId.startsWith('demo-') || buyerId == 'usr-buyer' || sellerId == 'usr-seller') {
        return 'room-demo';
      }

      // Fast-path: Check if chat room already exists between buyer and seller
      final existingChat = await _client
          .from('chats')
          .select('chat_id, inquiry_id')
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .limit(1)
          .maybeSingle();

      if (existingChat != null) {
        final chatId = existingChat['chat_id'] as String;
        // Un-delete chat states in background so both parties are active
        _client.from('chats').update({
          'deleted_by_buyer': false,
          'deleted_by_seller': false,
        }).eq('chat_id', chatId).catchError((_) {});

        // If the room has 0 messages, trigger the initial seller welcome message
        try {
          final existingMsgs = await _client
              .from('messages')
              .select('message_id')
              .eq('chat_id', chatId)
              .limit(1);

          if (existingMsgs == null || (existingMsgs as List).isEmpty) {
            await _sendInitialWelcomeMessage(
              chatId,
              sellerId,
              buyerId,
              productId,
              productName: productName,
              productPrice: productPrice,
            );
          }
        } catch (e) {
          debugPrint("CHECK_EXISTING_ROOM_MESSAGES_ERROR: $e");
        }

        return chatId;
      }

      // 1. Ensure buyer exists in users table
      final safeBuyer = buyerId.length > 5 ? buyerId.substring(0, 5) : buyerId;
      try {
        final buyerCheck = await _client.from('users').select('user_id').eq('user_id', buyerId).limit(1).maybeSingle();
        if (buyerCheck == null) {
          await _client.from('users').insert({
            'user_id': buyerId,
            'full_name': 'Wildcat Buyer',
            'email': 'buyer.$safeBuyer@cit.edu',
            'password_hash': 'pbkdf2_sha256\$260000\$dummyhashbuyer',
            'role': 'BUYER',
            'is_verified': true,
          });
        }
      } catch (e) {
        debugPrint("ENSURE_BUYER_ERROR: $e");
      }

      // Ensure seller exists in users table (violates chats_seller_id_fkey otherwise)
      final safeSeller = sellerId.length > 5 ? sellerId.substring(0, 5) : sellerId;
      try {
        final sellerCheck = await _client.from('users').select('user_id').eq('user_id', sellerId).limit(1).maybeSingle();
        if (sellerCheck == null) {
          await _client.from('users').insert({
            'user_id': sellerId,
            'full_name': 'Wildcat Seller',
            'email': 'seller.$safeSeller@cit.edu',
            'password_hash': 'pbkdf2_sha256\$260000\$dummyhashseller',
            'role': 'SELLER',
            'is_verified': true,
          });
        }
      } catch (e) {
        debugPrint("ENSURE_SELLER_ERROR: $e");
      }

      // 2. We need an inquiry first. Check for an existing product variant
      String variantId = 'var-standard';
      try {
        final productVariants = await _client
            .from('product_variants')
            .select('variant_id')
            .eq('product_id', productId)
            .limit(1);

        if (productVariants != null && (productVariants as List).isNotEmpty) {
          variantId = productVariants[0]['variant_id'] as String;
        } else {
          final safeProd = productId.length > 8 ? productId.substring(0, 8) : productId;
          final newVariant = await _client.from('product_variants').insert({
            'product_id': productId,
            'variant_name': 'Standard',
            'variant_value': 'Default',
            'sku': 'SKU-${safeProd.toUpperCase()}-DEFAULT',
          }).select().single();
          variantId = newVariant['variant_id'] as String;

          await _client.from('inventory').insert({
            'variant_id': variantId,
            'stock_qty': 10,
            'reserved_qty': 0,
          }).catchError((_) {});
        }
      } catch (e) {
        debugPrint("ENSURE_VARIANT_ERROR: $e");
      }

      // 3. Find or create inquiry
      String inquiryId = 'inq-${DateTime.now().millisecondsSinceEpoch}';
      try {
        final existingInquiry = await _client
            .from('inquiries')
            .select('inquiry_id')
            .eq('buyer_id', buyerId)
            .eq('product_id', productId)
            .limit(1)
            .maybeSingle();

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
      } catch (e) {
        debugPrint("ENSURE_INQUIRY_ERROR: $e");
      }

      // 4. Create the chat room linking to this inquiry
      final newChat = await _client.from('chats').insert({
        'inquiry_id': inquiryId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
      }).select().single();

      final chatId = newChat['chat_id'] as String;

      // Automatically post welcome message on chat room creation (FR-15 Shopee style)
      await _sendInitialWelcomeMessage(
        chatId,
        sellerId,
        buyerId,
        productId,
        productName: productName,
        productPrice: productPrice,
      );

      return chatId;
    } catch (e) {
      debugPrint("GET_OR_CREATE_CHAT_ROOM_ERROR: $e");
      // Graceful fallback for demo/offline test environments
      return 'room-demo';
    }
  }

  /// Sends the customizable welcome message containing the product context on chat creation
  Future<void> _sendInitialWelcomeMessage(
    String chatId,
    String sellerId,
    String buyerId,
    String productId, {
    String? productName,
    double? productPrice,
  }) async {
    try {
      // 1. Fetch seller profile settings (welcome template)
      String? template;
      try {
        final profile = await _client
            .from('store_profiles')
            .select('welcome_message_template')
            .eq('seller_id', sellerId)
            .maybeSingle();
        if (profile != null && profile['welcome_message_template'] != null) {
          template = profile['welcome_message_template'] as String;
        }
      } catch (e) {
        debugPrint("WELCOME_PROFILE_FETCH_ERROR: $e");
      }

      template ??= 'Hi! Thank you for inquiring about [PRODUCT]. The price is ₱[PRICE]. How can I help you?';

      // 2. Resolve product info (use passed parameters or fallback to database lookup)
      String resolvedProdName = productName ?? 'Product';
      double resolvedProdPrice = productPrice ?? 0.0;

      if (productName == null || productPrice == null) {
        try {
          final prod = await _client
              .from('products')
              .select('name, base_price')
              .eq('product_id', productId)
              .maybeSingle();

          if (prod != null) {
            resolvedProdName = prod['name'] as String? ?? resolvedProdName;
            resolvedProdPrice = double.tryParse(prod['base_price']?.toString() ?? '0') ?? resolvedProdPrice;
          }
        } catch (e) {
          debugPrint("WELCOME_PRODUCT_FETCH_ERROR: $e");
        }
      }

      // Swap template tokens with live product details
      final content = template
          .replaceAll('[PRODUCT]', resolvedProdName)
          .replaceAll('[PRICE]', resolvedProdPrice.toStringAsFixed(0));

      // Safely post initial seller welcome message via database RPC
      // without violating client-side RLS constraints
      await _client.rpc(
        'send_automated_chat_reply',
        params: {
          'p_chat_id': chatId,
          'p_content': content,
        },
      );
    } catch (e) {
      debugPrint("SEND_INITIAL_WELCOME_MESSAGE_ERROR: $e");
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
            debugPrint("WATCH_MESSAGES_DEBUG: roomId=$roomId, userId=${currentUser.id}, isBuyer=$isBuyer, clearedAt=$clearedAt");
          } else {
            debugPrint("WATCH_MESSAGES_DEBUG: Room data not found for roomId=$roomId");
          }
        } else {
          debugPrint("WATCH_MESSAGES_DEBUG: Current authenticated user is NULL");
        }

        var dbQuery = _client.from('messages').select('*').eq('chat_id', roomId);
        if (clearedAt != null) {
          dbQuery = dbQuery.gt('sent_at', clearedAt);
        }

        final response = await dbQuery.order('sent_at', ascending: true);
        debugPrint("WATCH_MESSAGES_DEBUG: Fetched ${response.length} messages after filtering");

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

        // Preserve in-flight / optimistic pending messages for this room
        final pending = _activeMessages.where((m) =>
            m.roomId == roomId && (m.id.startsWith('temp-') || m.id.startsWith('demo-'))).toList();

        _activeMessages.removeWhere((m) => m.roomId == roomId);
        _activeMessages.addAll(loaded);
        for (final p in pending) {
          if (!_activeMessages.any((m) => m.content == p.content && m.senderId == p.senderId)) {
            _activeMessages.add(p);
          }
        }
      } catch (e, stackTrace) {
        debugPrint("SUBSCRIBE_ROOM_READ_ERROR for room $roomId: $e");
        debugPrint(stackTrace.toString());
      }

      // Now yield the loaded database messages for this room
      yield getMessagesForRoom(roomId);

      // 2. Setup real-time listener asynchronously
      _subscribeToRealtime(roomId);
    } else {
      // Yield demo/memory messages for this room
      yield getMessagesForRoom(roomId);
    }

    // Yield any subsequent updates filtered for this specific room
    yield* _messageController.stream.map((messages) =>
        messages.where((m) => m.roomId == roomId).toList());
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
              (m.senderId == msg.senderId && m.content == msg.content && m.id.startsWith('temp-'))
            );
            
            if (!exists) {
              _activeMessages.add(msg);
              _messageController.add(List.from(_activeMessages));
            } else {
              // Update the optimistic temporary message with the actual database UUID and timestamp
              final index = _activeMessages.indexWhere((m) => 
                m.senderId == msg.senderId && m.content == msg.content && m.id.startsWith('temp-')
              );
              if (index != -1) {
                _activeMessages[index] = msg;
                _messageController.add(List.from(_activeMessages));
              }
            }
          },
        );
        
    _channel!.subscribe((status, [error]) {
      debugPrint("REALTIME_SUBSCRIPTION_STATUS for $chatId: $status, error: $error");
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
    // Clean up any previously failed attempts of the same message content
    _activeMessages.removeWhere((m) =>
        m.content == content &&
        m.senderId == senderId &&
        m.id.startsWith('failed-'));

    final isDemo = roomId == 'room-demo' || roomId.startsWith('demo-');
    final userMessage = Message(
      id: isDemo
          ? 'demo-msg-${DateTime.now().millisecondsSinceEpoch}'
          : 'temp-${DateTime.now().millisecondsSinceEpoch}',
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
        final newRow = await _client.from('messages').insert({
          'chat_id': roomId,
          'sender_id': senderId,
          'content': content,
          'image_url': imageUrl,
          'is_read': false,
        }).select().single();

        final msg = Message(
          id: newRow['message_id'] as String,
          senderId: newRow['sender_id'] as String,
          receiverId: '',
          content: newRow['content'] as String? ?? '',
          createdAt: DateTime.tryParse(newRow['sent_at'] as String? ?? '') ??
              DateTime.now(),
          roomId: roomId,
          imageUrl: newRow['image_url'] as String?,
        );

        final index = _activeMessages.indexWhere((m) => m.id == userMessage.id);
        if (index != -1) {
          _activeMessages[index] = msg;
          _messageController.add(List.from(_activeMessages));
        }

        // Trigger live auto-reply ONLY if the seller is offline
        if (senderId != receiverId && product != null) {
          // Check if seller has been active recently (within last 3 minutes) to determine online presence status
          bool isSellerOnline = false;
          try {
            final response = await _client
                .from('messages')
                .select('sent_at, content')
                .eq('chat_id', roomId)
                .eq('sender_id', receiverId)
                .order('sent_at', ascending: false)
                .limit(10);

            if (response != null && (response as List).isNotEmpty) {
              final list = response as List;
              for (final row in list) {
                final contentStr = row['content'] as String? ?? '';
                // Only consider messages that are NOT auto-replies to gauge human seller activity
                if (!_isAutoReply(contentStr)) {
                  final sentAtStr = row['sent_at'] as String?;
                  if (sentAtStr != null) {
                    final lastSent = DateTime.tryParse(sentAtStr) ?? DateTime.now();
                    if (DateTime.now().difference(lastSent).inMinutes < 3) {
                      isSellerOnline = true;
                    }
                  }
                  break; // Found the latest human seller message, stop checking
                }
              }
            }
          } catch (e) {
            debugPrint("PRESENCE_CHECK_AUTO_REPLY_ERROR: $e");
          }

          // Trigger auto-reply helper ONLY if seller is offline
          if (!isSellerOnline) {
            // Fetch custom seller settings dynamically from store_profiles
            String? customActiveHours;
            String? customMeetupSpots;
            String? sellerGcash;
            String? latestOrderStatus;
            try {
              final profile = await _client
                  .from('store_profiles')
                  .select('usual_active_hours, preferred_meetup_spots')
                  .eq('seller_id', receiverId) // receiverId is the seller
                  .maybeSingle();
              if (profile != null) {
                customActiveHours = profile['usual_active_hours'] as String?;
                customMeetupSpots = profile['preferred_meetup_spots'] as String?;
              }

              final sellerUser = await _client
                  .from('users')
                  .select('gcash_number')
                  .eq('user_id', receiverId)
                  .maybeSingle();
              if (sellerUser != null) {
                sellerGcash = sellerUser['gcash_number'] as String?;
              }

              final orderRecord = await _client
                  .from('orders')
                  .select('status')
                  .eq('buyer_id', senderId)
                  .eq('seller_id', receiverId)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              if (orderRecord != null) {
                latestOrderStatus = orderRecord['status'] as String?;
              }
            } catch (e) {
              debugPrint("AUTO_REPLY_FETCH_PROFILE_ERROR: $e");
            }

            final responseText = _getAssistantResponse(
              content, 
              product,
              activeHours: customActiveHours,
              meetupSpots: customMeetupSpots,
              gcashNumber: sellerGcash,
              orderStatus: latestOrderStatus,
            );

            if (responseText != null) {
              Future.delayed(const Duration(seconds: 2), () async {
                try {
                  // Safely post automated assistant reply via database RPC
                  // without violating client-side RLS constraints
                  await _client.rpc(
                    'send_automated_chat_reply',
                    params: {
                      'p_chat_id': roomId,
                      'p_content': responseText,
                    },
                  );
                } catch (e) {
                  debugPrint("LIVE_AUTO_REPLY_RPC_ERROR: $e");
                }
              });
            }
          }
        }
      } catch (e, stackTrace) {
        final index = _activeMessages.indexWhere((m) => m.id == userMessage.id);
        if (index != -1) {
          _activeMessages[index] = userMessage.copyWith(id: 'failed-${userMessage.id}');
          _messageController.add(List.from(_activeMessages));
        } else {
          _activeMessages.remove(userMessage);
          _messageController.add(List.from(_activeMessages));
        }
        debugPrint("SEND_MESSAGE_INSERT_ERROR: $e");
        debugPrint(stackTrace.toString());
        rethrow;
      }
      return;
    }

    // Demo negotiation auto-reply simulation using the Automated Chat Assistant rules
    // Only trigger if the buyer is the one sending the message (prevent self-reply/loops)
    if (senderId != receiverId && product != null) {
      final responseText = _getAssistantResponse(
        content,
        product,
        gcashNumber: '09171234567',
        orderStatus: 'APPROVED',
      );
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
  /// 4. Payment instructions
  /// 5. Order status
  String? _getAssistantResponse(
    String messageText, 
    Product product, {
    String? sellerFirstName,
    String? activeHours,
    String? meetupSpots,
    String? gcashNumber,
    String? orderStatus,
  }) {
    final msg = messageText.toLowerCase().trim();

    // Resolve seller first name: use provided name, fallback to 'Clarence' for demo, else 'the seller'
    final String resolvedSellerName = sellerFirstName ??
        (product.sellerId == 'demo-seller' || product.sellerId.startsWith('demo')
            ? 'Clarence'
            : 'the seller');

    const String responseTime = '10 minutes';
    const int stock = 3; // fallback stock for demo/unknown products

    // 0. Bargaining / Tawad / Offer Inquiry
    if (msg.contains('can we agree on ₱') || msg.contains('deal?') || msg.contains('tawad') || msg.contains('offer') || msg.contains('discount')) {
      double? offerPrice;
      final pesoMatch = RegExp(r'[₱pP]\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)').firstMatch(messageText);
      if (pesoMatch != null) {
        offerPrice = double.tryParse((pesoMatch.group(1) ?? '').replaceAll(',', ''));
      } else {
        final genericMatch = RegExp(r'\b([0-9]+(?:\.[0-9]{1,2})?)\b').firstMatch(messageText);
        if (genericMatch != null) {
          offerPrice = double.tryParse(genericMatch.group(1) ?? '');
        }
      }

      if (offerPrice != null && offerPrice > 0) {
        final originalPrice = product.price;
        final discountPercent = ((originalPrice - offerPrice) / originalPrice) * 100;

        // If discount is reasonable (within 25% of asking price), accept deal!
        if (discountPercent <= 25 && offerPrice <= originalPrice) {
          return "Sure! I can accept ₱${offerPrice.toStringAsFixed(0)}. Let's meet at the Library Lobby for the item exchange. Deal! 🤝";
        } else {
          final counterPrice = (originalPrice * 0.90).roundToDouble();
          return "That's a bit too low, sorry! The best I can do is ₱${counterPrice.toStringAsFixed(0)}. Can we agree on ₱${counterPrice.toStringAsFixed(0)}? Deal?";
        }
      } else {
        return "I'm open to reasonable offers (tawad)! How much are you proposing?";
      }
    }

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
      
      final String resolvedActive = (activeHours != null && activeHours != 'Not specified') ? activeHours : 'common hours';
      final String resolvedMeetup = (meetupSpots != null && meetupSpots != 'common campus locations') ? meetupSpots : 'common campus spots like the library, canteen, or guard post';

      return "Here are the preferred meetup spots & schedule for $resolvedSellerName:\n"
             "📍 Spots: $resolvedMeetup\n"
             "🕒 Schedule: $resolvedActive\n"
             "Please confirm if this schedule or location works for you!";
    }

    // 4. Payment Instructions Inquiry
    if (msg.contains('pay') || msg.contains('bayad') || msg.contains('gcash') || msg.contains('payment') || msg.contains('cash') || msg.contains('cod') || msg.contains('mode of payment') || msg.contains('mop')) {
      final gcashInfo = (gcashNumber != null && gcashNumber.isNotEmpty)
          ? "You can send GCash to the seller at: **$gcashNumber**."
          : "You can pay the seller directly in cash upon meetup.";
      return "For payment instructions, we support both Cash on Delivery/Meetup and GCash.\n$gcashInfo\nPlease verify references if using GCash.";
    }

    // 5. Order Status Inquiry
    if (msg.contains('status') || msg.contains('order') || msg.contains('delivered') || msg.contains('track') || msg.contains('delivery') || msg.contains('nasaan') || msg.contains('update')) {
      if (orderStatus != null && orderStatus.isNotEmpty) {
        String displayStatus = orderStatus;
        if (orderStatus == 'APPROVED') displayStatus = 'Approved (Reserved)';
        if (orderStatus == 'INQUIRY_SENT') displayStatus = 'Inquiry Sent / Pending Approval';
        if (orderStatus == 'COMPLETED') displayStatus = 'Completed';
        if (orderStatus == 'REJECTED') displayStatus = 'Rejected/Declined';
        return "Your latest order status is: **$displayStatus**.\nPlease check your order details in the app or let me know if you have any questions!";
      } else {
        return "You don't have any active orders with $resolvedSellerName yet. Proceed to checkout to place an order!";
      }
    }

    // No reply for unrecognized/ambiguous messages
    return null;
  }

  /// Helper to check if a message content belongs to the automated assistant replies
  bool _isAutoReply(String content) {
    final c = content.toLowerCase();
    return c.contains('thank you for inquiring about') ||
        c.contains('inquiring about') ||
        c.contains('final fixed price!') ||
        c.contains('is available. feel free to ask') ||
        c.contains('currently out of stock') ||
        c.contains('preferred meetup spots & schedule for') ||
        c.contains('for payment instructions, we support') ||
        c.contains('your latest order status is:') ||
        c.contains('sure! i can accept') ||
        c.contains('deal! 🤝') ||
        c.contains("that's a bit too low");
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
      debugPrint("SOFT_DELETE_CHAT_ROOM_ERROR: $e");
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
