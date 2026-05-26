import 'package:flutter/foundation.dart';

@immutable
class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final String roomId;
  final String? imageUrl; // Optional GCash receipt / proof attachment

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.roomId,
    this.imageUrl,
  });

  /// Factory constructor to create a Message from a Supabase/PostgreSQL JSON object.
  /// Handles both legacy test keys (id, room_id, created_at) and
  /// live Supabase schema keys (message_id, chat_id, sent_at).
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['message_id'] as String? ?? json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(
              json['sent_at'] as String? ?? json['created_at'] as String? ?? '') ??
          DateTime.now(),
      roomId: json['chat_id'] as String? ?? json['room_id'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }

  /// Converts the Message instance into a JSON map for database writes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,          // kept for test/legacy compatibility
      'sender_id': senderId,
      'content': content,
      'room_id': roomId, // kept for test/legacy compatibility
      'image_url': imageUrl,
    };
  }

  /// Creates a copy of the Message with modified fields, preserving immutability.
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? createdAt,
    String? roomId,
    String? imageUrl,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      roomId: roomId ?? this.roomId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          roomId == other.roomId;

  @override
  int get hashCode => id.hashCode ^ senderId.hashCode ^ roomId.hashCode;
}
