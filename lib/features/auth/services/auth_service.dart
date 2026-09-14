import 'dart:async';
import 'dart:convert';
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
      gcashNumber: user.userMetadata?['gcash_number'] as String?,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  bool isValidCituEmail(String email) {
    final lower = email.toLowerCase().trim();
    return lower.endsWith('@cit.edu');
  }

  bool isValidGeneralEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  // ── Sign In ──
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    if (!isValidGeneralEmail(email)) {
      throw const FormatException(
        'Please enter a valid email address.',
      );
    }

    final emailTrimmed = email.trim().toLowerCase();

    // Call server-authoritative backend /auth/login endpoint
    final url = Uri.parse('https://teknoycart-backend.onrender.com/api/auth/login');
    http.Response response;

    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailTrimmed,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw Exception('Unable to reach server. Please check your internet connection.');
    }

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode == 200) {
      // Establish Supabase session using the minted session returned by backend
      final sessionData = body['session'] as Map<String, dynamic>?;
      final refreshToken = sessionData?['refresh_token'] as String?;
      if (refreshToken != null) {
        await _client.auth.setSession(refreshToken);
      }

      final profile = currentUser;
      if (profile != null) {
        return profile;
      }

      // Fallback profile from backend response if auth state stream hasn't settled yet
      final userData = body['user'] as Map<String, dynamic>?;
      return Profile(
        id: userData?['userId'] as String? ?? '',
        username: userData?['fullName'] as String? ?? emailTrimmed.split('@').first,
        email: userData?['email'] as String? ?? emailTrimmed,
        createdAt: DateTime.now(),
      );
    }

    final errorType = body['type'] as String?;
    final errorMessage = body['message'] as String? ?? 'Authentication failed.';

    if (response.statusCode == 403) {
      if (errorType == 'EMAIL_UNVERIFIED') {
        throw UnverifiedEmailException(
          body['email'] as String? ?? emailTrimmed,
          body['fullName'] as String? ?? 'Student',
        );
      }
      // ACCOUNT_LOCKED or forbidden
      throw FormatException(errorMessage);
    }

    if (response.statusCode == 400) {
      throw FormatException(errorMessage);
    }

    throw Exception(errorMessage);
  }


  // ── Sign Up ──
  Future<Profile> signUp({
    required String email,
    required String username,
    required String password,
    required String role,
    required String studentId,
    String? department,
    String? storeName,
    String? sellerType,  // 'STUDENT' or 'ORG' (only for SELLER role)
    String? orgContact,  // contact number for ORG sellers
  }) async {
    if (role == 'BUYER') {
      if (!isValidCituEmail(email)) {
        throw const FormatException(
          'Strict Security Policy: Buyers must use an official @cit.edu email.',
        );
      }
    } else {
      if (!isValidGeneralEmail(email)) {
        throw const FormatException(
          'Please enter a valid store or contact email address.',
        );
      }
    }

    if (username.trim().isEmpty) {
      throw const FormatException('Username cannot be empty.');
    }
    if (password.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    final isOrgSeller = role == 'SELLER' && sellerType == 'ORG';

    // Only validate Student ID for BUYER and STUDENT sellers
    if (!isOrgSeller) {
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
          'student_id': isOrgSeller ? null : studentId.trim(),
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
        'student_id': isOrgSeller ? null : studentId.trim(),
        if (sellerType != null) 'seller_type': sellerType,
      });

      if (role == 'SELLER' && storeName != null && storeName.trim().isNotEmpty) {
        await _client.from('store_profiles').upsert({
          'seller_id': user.id,
          'store_name': storeName.trim(),
          if (isOrgSeller && orgContact != null && orgContact.trim().isNotEmpty)
            'contact_number': orgContact.trim(),
        });
      }

      // Trigger Spring Boot backend SMTP verification with retry
      await _sendVerificationEmailWithRetry(email, username);

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

  Future<void> resendVerificationEmail(String email, String fullName) async {
    await _sendVerificationEmailWithRetry(email, fullName);
  }

  Future<void> _sendVerificationEmailWithRetry(String email, String fullName) async {
    final url = Uri.parse('https://teknoycart-backend.onrender.com/api/auth/send-verification')
        .replace(queryParameters: {
          'email': email.trim(),
          'fullName': fullName.trim(),
        });

    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final httpResponse = await http.post(url).timeout(const Duration(seconds: 15));
        if (httpResponse.statusCode == 200) {
          print('✅ SMTP Verification email triggered successfully on attempt $attempts');
          return;
        } else {
          print('SMTP Trigger returned status code: ${httpResponse.statusCode}, attempt $attempts');
        }
      } catch (e) {
        print('Attempt $attempts: Failed to reach Spring Boot backend SMTP trigger ($e)');
      }
      if (attempts < 3) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
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
