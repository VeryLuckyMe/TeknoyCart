import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/core/config/api_config.dart';
import 'package:teknoycart/core/services/fcm_service.dart';
import 'package:http/http.dart' as http;

/// Authentication service backed by Supabase Auth.
/// Enforces @cit.edu / @cit.edu institutional email restriction.
class AuthService {
  /// Demo password policy: 12+ characters, no composition rules (D17).
  static const int minPasswordLength = 12;
  static bool passwordRecoveryPending = false;

  static bool isValidPasswordLength(String password) =>
      password.length >= minPasswordLength;

  // Lazy getter — avoids accessing SupabaseConfig.client before initialization
  SupabaseClient get _client => SupabaseConfig.client;

  /// Global flag to suppress authentication state stream changes during registration.
  /// Prevents Supabase's automatic login session from triggering root UI rebuilds.
  bool isRegistering = false;

  // ── Expose Supabase auth state as a Profile stream ──
  Stream<Profile?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      if (isRegistering) return null;
      if (event.event == AuthChangeEvent.passwordRecovery) {
        passwordRecoveryPending = true;
        return null;
      }
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
      role: (user.userMetadata?['role'] as String?) ?? 'BUYER',
      isSellerVerified:
          (user.userMetadata?['is_seller_verified'] as bool?) ?? false,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      department: user.userMetadata?['department'] as String?,
      contact: user.userMetadata?['contact'] as String?,
      studentId: user.userMetadata?['student_id'] as String?,
      gcashNumber: user.userMetadata?['gcash_number'] as String?,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  /// Enriches a profile with authoritative RBAC and profile data directly from the public.users database table.
  /// Prevents stale role/verification states when auth.users.raw_user_meta_data is out of sync.
  Future<Profile> getEnrichedProfile(Profile profile) async {
    try {
      // Own PII is exposed only through the owner-run my_profile view. The
      // base users table grants only public columns to authenticated clients.
      final res = await _client
          .from('my_profile')
          .select(
              'full_name, role, is_seller_verified, student_id, contact, gcash_number')
          .maybeSingle();
      if (res != null) {
        final meta = _client.auth.currentUser?.userMetadata;
        final dept = (meta?['department'] as String?) ?? profile.department;
        final avatar = (meta?['avatar_url'] as String?) ??
            (meta?['avatarUrl'] as String?) ??
            profile.avatarUrl;

        bool isVerified =
            (res['is_seller_verified'] as bool?) ?? profile.isSellerVerified;
        String userRole = res['role'] as String? ?? profile.role;

        // Check latest seller_verifications status to ensure instant sync upon admin approval
        if (!isVerified || userRole.toUpperCase() != 'SELLER') {
          try {
            final verif = await _client
                .from('seller_verifications')
                .select('status')
                .eq('user_id', profile.id)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (verif != null && verif['status'] == 'APPROVED') {
              isVerified = true;
              userRole = 'SELLER';
            }
          } catch (_) {}
        }

        return profile.copyWith(
          username: res['full_name'] as String? ?? profile.username,
          role: userRole,
          isSellerVerified: isVerified,
          department: dept,
          studentId: res['student_id'] as String? ?? profile.studentId,
          contact: res['contact'] as String? ?? profile.contact,
          gcashNumber: res['gcash_number'] as String? ?? profile.gcashNumber,
          avatarUrl: avatar,
        );
      }
    } catch (e) {
      debugPrint('AUTH_ENRICH_PROFILE: $e');
    }
    return profile;
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
    final url = Uri.parse('${ApiConfig.authUrl}/login');
    http.Response response;

    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': emailTrimmed,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw Exception(
          'Unable to reach server. Please check your internet connection.');
    }

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AUTH_LOGIN_PARSE: $e');
    }

    if (response.statusCode == 200) {
      // Establish Supabase session using the minted session returned by backend
      final sessionData = body['session'] as Map<String, dynamic>?;
      final accessToken = sessionData?['access_token'] as String?;
      final refreshToken = sessionData?['refresh_token'] as String?;
      final backendJwt = body['token'] as String?;

      // Securely store credentials via hardware-backed Keystore/Keychain (HIGH-01)
      await SecureTokenService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        backendToken: backendJwt,
      );

      if (refreshToken != null) {
        await _client.auth.setSession(refreshToken);
      }
      if (_client.auth.currentSession == null) {
        await SecureTokenService.clearTokens();
        throw Exception(
            'Failed to establish an authenticated Supabase session.');
      }

      final userData = body['user'] as Map<String, dynamic>?;
      final profile = currentUser;
      if (profile != null) {
        if (userData != null) {
          final backendRole = userData['role'] as String?;
          final backendVerified = (userData['isSellerVerified'] as bool?) ??
              (userData['is_seller_verified'] as bool?);
          final backendName = userData['fullName'] as String?;
          return profile.copyWith(
            username: backendName ?? profile.username,
            role: backendRole ?? profile.role,
            isSellerVerified: backendVerified ?? profile.isSellerVerified,
          );
        }
        return profile;
      }

      // Fallback profile from backend response if auth state stream hasn't settled yet
      return Profile(
        id: userData?['userId'] as String? ?? '',
        username:
            userData?['fullName'] as String? ?? emailTrimmed.split('@').first,
        email: userData?['email'] as String? ?? emailTrimmed,
        role: userData?['role'] as String? ?? 'BUYER',
        isSellerVerified: (userData?['isSellerVerified'] as bool?) ??
            (userData?['is_seller_verified'] as bool?) ??
            false,
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
      if (errorType == 'ACCOUNT_LOCKED') {
        DateTime? lockUntil;
        if (body['lockUntil'] != null) {
          lockUntil = DateTime.tryParse(body['lockUntil'].toString())?.toUtc();
        }
        final secs = body['remainingSeconds'] is num
            ? (body['remainingSeconds'] as num).toInt()
            : 600;
        throw AccountLockoutException(
          message: errorMessage,
          isLocked: true,
          attemptsRemaining: 0,
          remainingSeconds: secs,
          lockUntil: lockUntil,
        );
      }
      throw FormatException(errorMessage);
    }

    if (response.statusCode == 400) {
      final attempts = body['attemptsRemaining'] is num
          ? (body['attemptsRemaining'] as num).toInt()
          : null;
      if (attempts != null || errorMessage.contains('attempts remaining')) {
        throw AccountLockoutException(
          message: errorMessage,
          isLocked: false,
          attemptsRemaining: attempts,
        );
      }
      throw FormatException(errorMessage);
    }

    throw Exception(errorMessage);
  }

  // ── Sign Up ──
  Future<SignUpResult> signUp({
    required String email,
    required String username,
    required String password,
    required String role,
    required String studentId,
    String? department,
    String? storeName,
    String? sellerType, // 'STUDENT' or 'ORG' (only for SELLER role)
    String? orgContact, // contact number for ORG sellers
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
    if (!isValidPasswordLength(password)) {
      throw const FormatException('Password must be at least 12 characters.');
    }

    final isOrgSeller = role == 'SELLER' && sellerType == 'ORG';

    // Only validate Student ID for BUYER and STUDENT sellers
    if (!isOrgSeller) {
      final studentIdTrimmed = studentId.trim();
      final studentIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
      if (!studentIdRegex.hasMatch(studentIdTrimmed)) {
        throw const FormatException(
            'Student ID must follow the format ##-####-###.');
      }

      // The base users table no longer exposes student_id to anon. Ask the
      // SECURITY DEFINER RPC for a boolean without leaking another student's row.
      final available = await _client.rpc(
        'is_student_id_available',
        params: {'p_student_id': studentIdTrimmed},
      );

      if (available != true) {
        throw const FormatException('This Student ID is already registered.');
      }
    }

    // Set registration mode to true to suppress auth streams
    isRegistering = true;
    try {
      AuthResponse response;
      try {
        response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'username': username.trim(),
            'role': role,
            'student_id': isOrgSeller ? null : studentId.trim(),
            'department': department,
          },
        );
      } on AuthException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('already registered') ||
            message.contains('already exists')) {
          throw const FormatException(
            'This email already has an account. Sign in and resend the '
            'verification email, or register with a different email.',
          );
        }
        rethrow;
      }

      final user = response.user;
      if (user == null) {
        throw Exception('Registration failed. Please try again.');
      }
      if (response.session == null) {
        throw Exception(
          'Supabase email confirmation is enabled, but this app uses the '
          'backend SMTP verification flow. Disable Supabase email confirmation '
          'and try again.',
        );
      }

      // The INSERT trigger owns email, password_hash, verification flags and
      // lockout state. Clients may only submit the public signup columns, and
      // ignoreDuplicates avoids the UPDATE guard when the row already exists.
      await _client.from('users').upsert(
        {
          'user_id': user.id,
          'full_name': username.trim(),
          'role': role,
          'student_id': isOrgSeller ? null : studentId.trim(),
          if (sellerType != null) 'seller_type': sellerType,
        },
        ignoreDuplicates: true,
      );

      if (role == 'SELLER' &&
          storeName != null &&
          storeName.trim().isNotEmpty) {
        await _client.from('store_profiles').upsert(
          {
            'seller_id': user.id,
            'store_name': storeName.trim(),
            if (isOrgSeller &&
                orgContact != null &&
                orgContact.trim().isNotEmpty)
              'contact_number': orgContact.trim(),
          },
          onConflict: 'seller_id',
        );
      }

      // The account already exists at this point. A verification-email outage
      // must not turn a successful registration into a dead end, so report the
      // delivery failure to the caller instead of throwing it.
      var verificationEmailSent = true;
      String? verificationEmailError;
      try {
        await sendVerificationEmail(email, username);
      } on VerificationEmailException catch (e) {
        verificationEmailSent = false;
        verificationEmailError = e.message;
      }

      // Instantly sign out to clear the session locally, since we're still in registration mode
      await _client.auth.signOut();

      return SignUpResult(
        profile: _userToProfile(user),
        verificationEmailSent: verificationEmailSent,
        verificationEmailError: verificationEmailError,
      );
    } catch (_) {
      // A failed profile step must not leave the temporary signup session active.
      try {
        await _client.auth.signOut();
      } catch (_) {}
      rethrow;
    } finally {
      isRegistering = false;
    }
  }

  // ── Sign Out ──
  Future<void> signOut() async {
    try {
      await FcmService.instance.unregisterToken();
    } catch (_) {}
    await SecureTokenService.clearTokens();
    await _client.auth.signOut();
  }

  Future<void> resendVerificationEmail(String email, String fullName) async {
    await sendVerificationEmail(email, fullName);
  }

  Future<void> sendVerificationEmail(String email, String fullName) async {
    final url = Uri.parse('${ApiConfig.authUrl}/send-verification');
    http.Response httpResponse;
    try {
      httpResponse = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'email': email.trim(), 'fullName': fullName.trim()}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const VerificationEmailException(
        'The verification service took too long to respond. Please check your connection and try again.',
      );
    } catch (_) {
      throw const VerificationEmailException(
        'Unable to reach the verification service. Please check your internet connection and try again.',
      );
    }

    if (httpResponse.statusCode == 200) return;

    throw VerificationEmailException(
      _verificationEmailErrorMessage(httpResponse),
    );
  }

  String _verificationEmailErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Non-JSON body — fall through to the status-based message.
    }

    final plainText = response.body.trim();
    if (plainText.startsWith('Error:')) {
      return plainText.substring('Error:'.length).trim();
    }

    if (response.statusCode == 429) {
      return 'Please wait a minute before requesting another verification email.';
    }
    if (response.statusCode >= 500) {
      return 'The verification service is temporarily unavailable. Please try again in a few minutes.';
    }
    return 'The verification email could not be sent. Please try again later.';
  }

  void dispose() {
    // Supabase client manages its own lifecycle
  }
}

/// Raised when the backend verification-email endpoint cannot be reached or
/// rejects the request. [message] is user-safe and surfaced by the dialog.
class VerificationEmailException implements Exception {
  final String message;
  const VerificationEmailException(this.message);

  @override
  String toString() => message;
}

/// Outcome of a successful sign-up. The account is always created; the
/// delivery flag only reports whether the verification link was dispatched.
class SignUpResult {
  final Profile profile;
  final bool verificationEmailSent;
  final String? verificationEmailError;

  const SignUpResult({
    required this.profile,
    this.verificationEmailSent = true,
    this.verificationEmailError,
  });
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

/// Custom Exception thrown when login fails due to incorrect credentials or active account lockout.
/// Holds attempts remaining and cooldown duration for UI/UX Pro Max countdown & live badge indicators.
class AccountLockoutException implements Exception {
  final String message;
  final bool isLocked;
  final int? attemptsRemaining;
  final int? remainingSeconds;
  final DateTime? lockUntil;

  AccountLockoutException({
    required this.message,
    this.isLocked = false,
    this.attemptsRemaining,
    this.remainingSeconds,
    this.lockUntil,
  });

  @override
  String toString() => message;
}
