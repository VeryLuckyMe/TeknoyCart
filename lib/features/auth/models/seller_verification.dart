import 'package:flutter/foundation.dart';

@immutable
class SellerVerification {
  final String id;
  final String userId;
  final String sellerType; // 'STUDENT' or 'ORG'
  final String? officerName;
  final String? officerPosition;
  final String idCardUrl;
  final String selfieUrl;
  final String? idCardStoragePath;
  final String? selfieStoragePath;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SellerVerification({
    required this.id,
    required this.userId,
    this.sellerType = 'STUDENT',
    this.officerName,
    this.officerPosition,
    required this.idCardUrl,
    required this.selfieUrl,
    this.idCardStoragePath,
    this.selfieStoragePath,
    this.status = 'PENDING',
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isOrg => sellerType.toUpperCase() == 'ORG';

  factory SellerVerification.fromJson(Map<String, dynamic> json) {
    return SellerVerification(
      id: (json['id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      sellerType: (json['seller_type'] as String?) ?? 'STUDENT',
      officerName: json['officer_name'] as String?,
      officerPosition: json['officer_position'] as String?,
      idCardUrl: (json['id_card_url'] ?? '') as String,
      selfieUrl: (json['selfie_url'] ?? '') as String,
      idCardStoragePath: json['id_card_storage_path'] as String?,
      selfieStoragePath: json['selfie_storage_path'] as String?,
      status: (json['status'] as String?) ?? 'PENDING',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'seller_type': sellerType,
      'officer_name': officerName,
      'officer_position': officerPosition,
      'id_card_url': idCardUrl,
      'selfie_url': selfieUrl,
      'id_card_storage_path': idCardStoragePath,
      'selfie_storage_path': selfieStoragePath,
      'status': status,
      'rejection_reason': rejectionReason,
    };
  }
}
