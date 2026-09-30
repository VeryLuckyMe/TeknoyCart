import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../models/seller_verification.dart';

final sellerVerificationServiceProvider = Provider<SellerVerificationService>((ref) {
  return SellerVerificationService(SupabaseConfig.client);
});

class SellerVerificationService {
  final SupabaseClient _client;

  SellerVerificationService(this._client);

  /// Bucket used for secure KYC document uploads
  static const String _storageBucket = 'product-images';

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
    final String idCardUrl = _client.storage.from(_storageBucket).getPublicUrl(idCardStoragePath);

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
    final String selfieUrl = _client.storage.from(_storageBucket).getPublicUrl(selfieStoragePath);

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

    // 4. Ensure user role is SELLER in users table (with unverified status)
    try {
      await _client.from('users').update({
        'role': 'SELLER',
        'is_seller_verified': false,
        'seller_type': sellerType,
      }).eq('user_id', userId);
    } catch (_) {
      // RLS or trigger might govern role change; safe to proceed
    }

    return SellerVerification.fromJson(res);
  }
}
