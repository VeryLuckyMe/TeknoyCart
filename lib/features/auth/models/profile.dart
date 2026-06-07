import 'package:flutter/foundation.dart';

@immutable
class Profile {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? department;
  final String? contact;
  final String? studentId;
  final String? gcashNumber;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.department,
    this.contact,
    this.studentId,
    this.gcashNumber,
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
      studentId: json['student_id'] as String?,
      gcashNumber: json['gcash_number'] as String?,
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
      'student_id': studentId,
      'gcash_number': gcashNumber,
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
    String? studentId,
    String? gcashNumber,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      department: department ?? this.department,
      contact: contact ?? this.contact,
      studentId: studentId ?? this.studentId,
      gcashNumber: gcashNumber ?? this.gcashNumber,
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
          studentId == other.studentId &&
          gcashNumber == other.gcashNumber &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      email.hashCode ^
      avatarUrl.hashCode ^
      department.hashCode ^
      contact.hashCode ^
      studentId.hashCode ^
      gcashNumber.hashCode ^
      createdAt.hashCode;
}
