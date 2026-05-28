import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';

/// Authentication service backed by Supabase Auth.
/// Enforces @cit.edu / @cit.edu institutional email restriction.
class AuthService {
  // Lazy getter — avoids accessing SupabaseConfig.client before initialization
  SupabaseClient get _client => SupabaseConfig.client;

  // ── Expose Supabase auth state as a Profile stream ──
  Stream<Profile?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? _userToProfile(user) : null;
    });
  }

  Profile? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? _userToProfile(user) : null;
  }

  Profile _userToProfile(User user) {
    return Profile(
      id: user.id,
      username: user.userMetadata?['username'] as String? ??
          (user.email?.split('@').first ?? 'student'),
      email: user.email ?? '',
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      department: user.userMetadata?['department'] as String?,
      contact: user.userMetadata?['contact'] as String?,
      studentId: user.userMetadata?['student_id'] as String?,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  bool isValidCituEmail(String email) {
    final lower = email.toLowerCase().trim();
    return lower.endsWith('@cit.edu');
  }

  // ── Sign In ──
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    if (!isValidCituEmail(email)) {
      throw const FormatException(
        'Strict Security Policy: Only @cit.edu emails are allowed.',
      );
    }

    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Authentication failed. Please check your credentials.');
    }

    return _userToProfile(user);
  }

  // ── Sign Up ──
  Future<Profile> signUp({
    required String email,
    required String username,
    required String password,
    required String role,
    required String studentId,
  }) async {
    if (!isValidCituEmail(email)) {
      throw const FormatException(
        'Strict Security Policy: Only @cit.edu domains are permitted.',
      );
    }
    if (username.trim().isEmpty) {
      throw const FormatException('Username cannot be empty.');
    }
    if (password.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    final studentIdTrimmed = studentId.trim();
    final studentIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
    if (!studentIdRegex.hasMatch(studentIdTrimmed)) {
      throw const FormatException('Student ID must follow the format ##-####-###.');
    }

    // Check if the Student ID is already registered in the DB
    final existingUser = await _client
        .from('users')
        .select('user_id')
        .eq('student_id', studentIdTrimmed)
        .maybeSingle();

    if (existingUser != null) {
      throw const FormatException('This Student ID is already registered.');
    }

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': username.trim(), 'role': role, 'student_id': studentIdTrimmed},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed. Please try again.');
    }

    // Insert into users table for RBAC tracking
    await _client.from('users').upsert({
      'user_id': user.id,
      'full_name': username.trim(),
      'email': email.trim(),
      'password_hash': 'SUPABASE_AUTH_MANAGED',
      'role': role,
      'is_verified': role == 'BUYER' ? true : false, // Buyers approved auto, Sellers pending
      'student_id': studentIdTrimmed,
    });

    return _userToProfile(user);
  }

  // ── Sign Out ──
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  void dispose() {
    // Supabase client manages its own lifecycle
  }
}
