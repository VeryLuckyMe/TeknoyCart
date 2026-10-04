import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/supabase_client.dart';
import '../../../core/services/secure_token_service.dart';
import '../models/seller_verification.dart';

final sellerVerificationServiceProvider = Provider<SellerVerificationService>((ref) {
  return SellerVerificationService(SupabaseConfig.client);
});

class SellerVerificationService {
  final SupabaseClient _client;

  SellerVerificationService(this._client);

  /// Private bucket used for secure KYC document uploads under RA 10173 Zero-Retention
  static const String _storageBucket = 'seller-kyc-documents';

  /// Fetches the latest verification submission for a user
  Future<SellerVerification?> getLatestVerification(String userId) async {
    try {
      final res = await _client
          .from('seller_verifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return SellerVerification.fromJson(res);
    } catch (e) {
      return null;
    }
  }

  /// Uploads KYC documents and submits the verification request
  Future<SellerVerification> submitVerification({
    required String userId,
    required String sellerType, // 'STUDENT' or 'ORG'
    String? officerName,
    String? officerPosition,
    required XFile idCardFile,
    required XFile selfieFile,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final idCardStoragePath = 'kyc/$userId/id_${timestamp}.jpg';
    final selfieStoragePath = 'kyc/$userId/selfie_${timestamp}.jpg';

    // 1. Upload ID card image
    final Uint8List idBytes = await idCardFile.readAsBytes();
    await _client.storage.from(_storageBucket).uploadBinary(
          idCardStoragePath,
          idBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    String idCardUrl;
    try {
      idCardUrl = await _client.storage.from(_storageBucket).createSignedUrl(idCardStoragePath, 604800);
    } catch (_) {
      idCardUrl = _client.storage.from(_storageBucket).getPublicUrl(idCardStoragePath);
    }

    // 2. Upload Selfie with ID image
    final Uint8List selfieBytes = await selfieFile.readAsBytes();
    await _client.storage.from(_storageBucket).uploadBinary(
          selfieStoragePath,
          selfieBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    String selfieUrl;
    try {
      selfieUrl = await _client.storage.from(_storageBucket).createSignedUrl(selfieStoragePath, 604800);
    } catch (_) {
      selfieUrl = _client.storage.from(_storageBucket).getPublicUrl(selfieStoragePath);
    }

    // 3. Insert new verification record
    final insertData = {
      'user_id': userId,
      'seller_type': sellerType,
      'officer_name': officerName?.trim().isNotEmpty == true ? officerName!.trim() : null,
      'officer_position': officerPosition?.trim().isNotEmpty == true ? officerPosition!.trim() : null,
      'id_card_url': idCardUrl,
      'selfie_url': selfieUrl,
      'id_card_storage_path': idCardStoragePath,
      'selfie_storage_path': selfieStoragePath,
      'status': 'PENDING',
      'rejection_reason': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final res = await _client
        .from('seller_verifications')
        .insert(insertData)
        .select()
        .single();

    // 4. Route role change through server-authoritative backend API (CRIT-02)
    // Never mutate role/is_seller_verified directly from the client — the RLS
    // trigger protect_user_security_columns() blocks this by design.
    try {
      final token = await SecureTokenService.getBearerToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://teknoycart-backend.onrender.com/api/auth/request-seller-upgrade'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          debugPrint('SELLER_UPGRADE_API: Backend returned ${response.statusCode}');
        }
      } else {
        debugPrint('SELLER_UPGRADE_API: No bearer token available, skipping backend call');
      }
    } catch (e) {
      debugPrint('SELLER_UPGRADE_API: Backend unreachable ($e), role change pending admin action');
    }

    return SellerVerification.fromJson(res);
  }
}
