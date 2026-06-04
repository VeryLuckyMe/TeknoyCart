import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:http/http.dart' as http;

/// Authentication service backed by Supabase Auth.
/// Enforces @cit.edu / @cit.edu institutional email restriction.
class AuthService {
  // Lazy getter — avoids accessing SupabaseConfig.client before initialization
  SupabaseClient get _client => SupabaseConfig.client;

  /// Global flag to suppress authentication state stream changes during registration.
  /// Prevents Supabase's automatic login session from triggering root UI rebuilds.
  bool isRegistering = false;

  // ── Expose Supabase auth state as a Profile stream ──
  Stream<Profile?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      if (isRegistering) return null;
      final user = event.session?.user;
      return user != null ? _userToProfile(user) : null;
    });
  }

  Profile? get currentUser {
    if (isRegistering) return null;
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

    final emailTrimmed = email.trim().toLowerCase();

    // Check database for lockout status and email verification status
    final userRecord = await _client
        .from('users')
        .select('is_locked, failed_attempts, lock_until, is_verified, full_name')
        .eq('email', emailTrimmed)
        .maybeSingle();

    if (userRecord != null) {
      final isVerified = userRecord['is_verified'] as bool? ?? false;
      if (!isVerified) {
        throw UnverifiedEmailException(
          emailTrimmed,
          userRecord['full_name'] as String? ?? 'Student',
        );
      }

      final isLocked = userRecord['is_locked'] as bool? ?? false;
      final lockUntilStr = userRecord['lock_until'] as String?;
      if (isLocked && lockUntilStr != null) {
        final lockUntil = DateTime.parse(lockUntilStr);
        if (DateTime.now().isBefore(lockUntil)) {
          final remaining = lockUntil.difference(DateTime.now()).inMinutes;
          final secs = lockUntil.difference(DateTime.now()).inSeconds % 60;
          throw FormatException(
            'Account locked. 5 failed login attempts. Try again in $remaining min, $secs sec.',
          );
        } else {
          // Lock duration expired: reset parameters in database
          await _client.from('users').update({
            'is_locked': false,
            'failed_attempts': 0,
            'lock_until': null,
          }).eq('email', emailTrimmed);
        }
      }
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Authentication failed. Please check your credentials.');
      }

      // Reset lockout columns on successful login
      await _client.from('users').update({
        'is_locked': false,
        'failed_attempts': 0,
        'lock_until': null,
      }).eq('email', emailTrimmed);

      return _userToProfile(user);
    } catch (e) {
      if (userRecord != null) {
        final currentAttempts = (userRecord['failed_attempts'] as int? ?? 0) + 1;
        if (currentAttempts >= 5) {
          final lockTime = DateTime.now().add(const Duration(minutes: 15));
          await _client.from('users').update({
            'is_locked': true,
            'failed_attempts': currentAttempts,
            'lock_until': lockTime.toIso8601String(),
          }).eq('email', emailTrimmed);
          
          throw const FormatException(
            'Too many failed attempts. Account locked for 15 minutes.',
          );
        } else {
          await _client.from('users').update({
            'failed_attempts': currentAttempts,
          }).eq('email', emailTrimmed);
          
          final remaining = 5 - currentAttempts;
          throw FormatException(
            'Incorrect password. $remaining attempts remaining before lockout.',
          );
        }
      }
      rethrow;
    }
  }

  // ── Sign Up ──
  Future<Profile> signUp({
    required String email,
    required String username,
    required String password,
    required String role,
    required String studentId,
    String? department,
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

    // Set registration mode to true to suppress auth streams
    isRegistering = true;
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim(),
          'role': role,
          'student_id': studentIdTrimmed,
          'department': department,
        },
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
        'is_verified': false, // Force Outlook email verification for all roles (FR-01)
        'student_id': studentIdTrimmed,
      });

      try {
        final url = Uri.parse('https://teknoycart-backend.onrender.com/api/auth/send-verification')
            .replace(queryParameters: {
              'email': email.trim(),
              'fullName': username.trim(),
            });
        final httpResponse = await http.post(url);
        if (httpResponse.statusCode != 200) {
          print('SMTP Trigger status code: ${httpResponse.statusCode}, body: ${httpResponse.body}');
        }
      } catch (e) {
        print('Failed to reach Spring Boot backend SMTP trigger: $e');
      }

      // Instantly sign out to clear the session locally, since we're still in registration mode
      await _client.auth.signOut();

      return _userToProfile(user);
    } finally {
      // Delay resetting to allow the stream events to settle down and be ignored
      Future.delayed(const Duration(milliseconds: 600), () {
        isRegistering = false;
      });
    }
  }

  // ── Sign Out ──
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  void dispose() {
    // Supabase client manages its own lifecycle
  }
}

/// Custom Exception thrown when a user attempts to log in but their email is unverified.
/// Houses the email and full name to cleanly trigger UX resend prompts without state loss.
class UnverifiedEmailException implements Exception {
  final String email;
  final String fullName;
  UnverifiedEmailException(this.email, this.fullName);

  @override
  String toString() => 'EMAIL_UNVERIFIED_PENDING: $email|$fullName';
}
