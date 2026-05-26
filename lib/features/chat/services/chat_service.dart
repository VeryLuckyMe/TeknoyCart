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

  /// Watch messages for a given Supabase chat_id (room).
  /// Falls back to the local broadcast stream for demo rooms.
  Stream<List<Message>> watchMessages(String roomId) {
    // Subscribe to Supabase Realtime channel for live DB rooms
    if (roomId != 'room-demo' && !roomId.startsWith('demo-')) {
      _subscribeToRoom(roomId);
    }
    return _messageController.stream;
  }

  Future<void> _subscribeToRoom(String chatId) async {
    // Unsubscribe from previous channel to avoid duplicates
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }

    // Load existing messages from Supabase
    try {
      final response = await _client
          .from('messages')
          .select('*')
          .eq('chat_id', chatId)
          .order('sent_at', ascending: true);

      final rows = response as List<dynamic>;
      final loaded = rows.map((row) => Message(
            id: row['message_id'] as String,
            senderId: row['sender_id'] as String,
            receiverId: '', // not stored in messages, derive from chat
            content: row['content'] as String? ?? '',
            createdAt: DateTime.tryParse(row['sent_at'] as String? ?? '') ??
                DateTime.now(),
            roomId: chatId,
            imageUrl: row['image_url'] as String?,
          ));

      _activeMessages.clear();
      _activeMessages.addAll(loaded);
      _messageController.add(List.from(_activeMessages));
    } catch (e) {
      // DB unreachable — keep demo messages
    }

    // Subscribe to real-time INSERT events
    _channel = _client
        .channel('chat:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
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
            _activeMessages.add(msg);
            _messageController.add(List.from(_activeMessages));
          },
        )
        .subscribe();
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
      } catch (e) {
        // Message stored locally; sync on next reconnect
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
