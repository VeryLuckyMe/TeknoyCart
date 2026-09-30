import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teknoycart/features/auth/models/seller_verification.dart';
import 'package:teknoycart/features/auth/services/seller_verification_service.dart';
import 'package:teknoycart/features/auth/views/widgets/seller_kyc_verification_view.dart';

class MockSellerVerificationService implements SellerVerificationService {
  SellerVerification? mockVerification;

  @override
  Future<SellerVerification?> getLatestVerification(String userId) async {
    return mockVerification;
  }

  @override
  Future<SellerVerification> submitVerification({
    required String userId,
    required String sellerType,
    String? officerName,
    String? officerPosition,
    required XFile idCardFile,
    required XFile selfieFile,
  }) async {
    final sub = SellerVerification(
      id: 'test-verif-uuid',
      userId: userId,
      sellerType: sellerType,
      officerName: officerName,
      officerPosition: officerPosition,
      idCardUrl: 'https://example.com/id.jpg',
      selfieUrl: 'https://example.com/selfie.jpg',
      idCardStoragePath: 'kyc/$userId/id_test.jpg',
      selfieStoragePath: 'kyc/$userId/selfie_test.jpg',
      status: 'PENDING',
    );
    mockVerification = sub;
    return sub;
  }
}

void main() {
  group('SellerVerification Model & Logic Unit Tests', () {
    test('Correctly parses SellerVerification from JSON and handles status getters', () {
      final json = {
        'id': 'verif-123',
        'user_id': 'user-456',
        'seller_type': 'ORG',
        'officer_name': 'Juan Dela Cruz',
        'officer_position': 'Treasurer',
        'id_card_url': 'https://storage.supabase.co/kyc/id.jpg',
        'selfie_url': 'https://storage.supabase.co/kyc/selfie.jpg',
        'id_card_storage_path': 'kyc/user-456/id.jpg',
        'selfie_storage_path': 'kyc/user-456/selfie.jpg',
        'status': 'PENDING',
        'rejection_reason': null,
      };

      final record = SellerVerification.fromJson(json);

      expect(record.id, 'verif-123');
      expect(record.userId, 'user-456');
      expect(record.isOrg, isTrue);
      expect(record.officerName, 'Juan Dela Cruz');
      expect(record.officerPosition, 'Treasurer');
      expect(record.isPending, isTrue);
      expect(record.isApproved, isFalse);
      expect(record.isRejected, isFalse);
    });

    test('Correctly handles REJECTED status with rejectionReason', () {
      final json = {
        'id': 'verif-999',
        'user_id': 'user-888',
        'seller_type': 'STUDENT',
        'id_card_url': 'https://storage.supabase.co/kyc/id.jpg',
        'selfie_url': 'https://storage.supabase.co/kyc/selfie.jpg',
        'status': 'REJECTED',
        'rejection_reason': 'Photo is blurry. Please retake under bright light.',
      };

      final record = SellerVerification.fromJson(json);

      expect(record.isRejected, isTrue);
      expect(record.isPending, isFalse);
      expect(record.isOrg, isFalse);
      expect(record.rejectionReason, contains('Photo is blurry'));
    });

    test('toJson generates appropriate payload including zero-retention storage paths', () {
      const record = SellerVerification(
        id: 'verif-101',
        userId: 'user-202',
        sellerType: 'STUDENT',
        idCardUrl: 'https://storage.supabase.co/id.jpg',
        selfieUrl: 'https://storage.supabase.co/selfie.jpg',
        idCardStoragePath: 'kyc/user-202/id.jpg',
        selfieStoragePath: 'kyc/user-202/selfie.jpg',
        status: 'PENDING',
      );

      final map = record.toJson();

      expect(map['user_id'], 'user-202');
      expect(map['id_card_storage_path'], 'kyc/user-202/id.jpg');
      expect(map['selfie_storage_path'], 'kyc/user-202/selfie.jpg');
      expect(map['status'], 'PENDING');
    });
  });

  group('SellerKYCVerificationView Widget Tests', () {
    late MockSellerVerificationService mockService;

    setUp(() {
      mockService = MockSellerVerificationService();
    });

    Widget createTestApp({
      required String userId,
      String initialSellerType = 'STUDENT',
    }) {
      return ProviderScope(
        overrides: [
          sellerVerificationServiceProvider.overrideWithValue(mockService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SellerKYCVerificationView(
              userId: userId,
              initialSellerType: initialSellerType,
            ),
          ),
        ),
      );
    }

    testWidgets('Renders KYC form with card upload options and honor code agreement', (tester) async {
      await tester.pumpWidget(createTestApp(userId: 'test-user-1'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Campus Seller Verification'), findsOneWidget);
      expect(find.text('Verify student status to start listing items'), findsOneWidget);

      // Verify Card 1 & Card 2
      expect(find.text('1. CIT Student ID Card (Front)'), findsOneWidget);
      expect(find.text('2. Selfie Holding CIT ID Card'), findsOneWidget);

      // Verify Honor Code Agreement
      expect(find.text('CIT-U Campus Vendor Honor Code'), findsOneWidget);
      expect(find.text('I have read and agree to the Campus Vendor Honor Code and Privacy Consent.'), findsOneWidget);

      // Verify Submit Button exists
      expect(find.text('Submit Verification for Review'), findsOneWidget);
    });

    testWidgets('Renders Lead Officer fields when sellerType is ORG', (tester) async {
      await tester.pumpWidget(createTestApp(userId: 'org-user-1', initialSellerType: 'ORG'));
      await tester.pumpAndSettle();

      expect(find.text('Lead Officer Custodian (Shopee Model)'), findsOneWidget);
      expect(find.text('Lead Officer Full Name'), findsOneWidget);
      expect(find.text('Officer Position (e.g. President, Treasurer)'), findsOneWidget);
    });

    testWidgets('Renders Under Review state when verification is PENDING', (tester) async {
      mockService.mockVerification = const SellerVerification(
        id: 'verif-pending-1',
        userId: 'pending-user',
        idCardUrl: 'https://example.com/id.jpg',
        selfieUrl: 'https://example.com/selfie.jpg',
        status: 'PENDING',
      );

      await tester.pumpWidget(createTestApp(userId: 'pending-user'));
      await tester.pumpAndSettle();

      expect(find.text('Verification Under Review'), findsOneWidget);
      expect(find.text('Refresh Review Status'), findsOneWidget);
      expect(find.text('Zero-Retention KYC: Photos will be purged upon decision.'), findsOneWidget);
    });

    testWidgets('Renders rejection alert banner when previous submission was REJECTED', (tester) async {
      mockService.mockVerification = const SellerVerification(
        id: 'verif-rejected-1',
        userId: 'rejected-user',
        idCardUrl: 'https://example.com/id.jpg',
        selfieUrl: 'https://example.com/selfie.jpg',
        status: 'REJECTED',
        rejectionReason: 'ID card was too blurry to read the student ID number.',
      );

      await tester.pumpWidget(createTestApp(userId: 'rejected-user'));
      await tester.pumpAndSettle();

      expect(find.text('Resubmission Required'), findsOneWidget);
      expect(find.text('ID card was too blurry to read the student ID number.'), findsOneWidget);
      // Still shows form so user can resubmit
      expect(find.text('Submit Verification for Review'), findsOneWidget);
    });
  });
}
