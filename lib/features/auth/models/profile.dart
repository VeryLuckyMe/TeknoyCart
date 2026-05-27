import 'package:flutter/foundation.dart';

@immutable
class Profile {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? department;
  final String? contact;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.department,
    this.contact,
    required this.createdAt,
  });

  /// Factory constructor to create a Profile from a Supabase/PostgreSQL JSON object.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      department: json['department'] as String?,
      contact: json['contact'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts the Profile instance into a JSON map for database writes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'department': department,
      'contact': contact,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of the Profile with modified fields, preserving immutability.
  Profile copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? department,
    String? contact,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      department: department ?? this.department,
      contact: contact ?? this.contact,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          email == other.email &&
          avatarUrl == other.avatarUrl &&
          department == other.department &&
          contact == other.contact &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      email.hashCode ^
      avatarUrl.hashCode ^
      department.hashCode ^
      contact.hashCode ^
      createdAt.hashCode;
}
