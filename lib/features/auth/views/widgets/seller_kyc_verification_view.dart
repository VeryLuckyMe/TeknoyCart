import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme.dart';
import '../../models/seller_verification.dart';
import '../../services/seller_verification_service.dart';

/// Embedded or standalone view for submitting student and organization KYC seller verification.
/// Strictly follows Zero-Retention privacy policy (photos deleted upon review under RA 10173).
/// Zero emojis used — only crisp vector icons.
class SellerKYCVerificationView extends ConsumerStatefulWidget {
  final String userId;
  final String initialSellerType; // 'STUDENT' or 'ORG'
  final VoidCallback? onVerificationSubmitted;
  final VoidCallback? onRefreshStatus;
  final bool embedded;

  const SellerKYCVerificationView({
    super.key,
    required this.userId,
    this.initialSellerType = 'STUDENT',
    this.onVerificationSubmitted,
    this.onRefreshStatus,
    this.embedded = true,
  });

  @override
  ConsumerState<SellerKYCVerificationView> createState() => _SellerKYCVerificationViewState();
}

class _SellerKYCVerificationViewState extends ConsumerState<SellerKYCVerificationView> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _officerNameController = TextEditingController();
  final _officerPositionController = TextEditingController();

  XFile? _idCardFile;
  XFile? _selfieFile;

  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;

  SellerVerification? _existingVerification;
  late String _sellerType;

  @override
  void initState() {
    super.initState();
    _sellerType = widget.initialSellerType;
    _fetchVerificationHistory();
  }

  @override
  void dispose() {
    _officerNameController.dispose();
    _officerPositionController.dispose();
    super.dispose();
  }

  Future<void> _fetchVerificationHistory() async {
    setState(() => _isLoadingHistory = true);
    final service = ref.read(sellerVerificationServiceProvider);
    final record = await service.getLatestVerification(widget.userId);
    if (mounted) {
      setState(() {
        _existingVerification = record;
        if (record != null) {
          _sellerType = record.sellerType;
          if (record.officerName != null) {
            _officerNameController.text = record.officerName!;
          }
          if (record.officerPosition != null) {
            _officerPositionController.text = record.officerPosition!;
          }
        }
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _pickImage({
    required bool isIdCard,
    required ImageSource source,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (picked != null && mounted) {
        setState(() {
          if (isIdCard) {
            _idCardFile = picked;
          } else {
            _selfieFile = picked;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: TeknoyTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    if (_idCardFile == null || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture both your CIT ID card and your selfie holding the ID.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    if (_sellerType == 'ORG') {
      if (_officerNameController.text.trim().isEmpty || _officerPositionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide the Lead Officer name and official position for the organization.'),
            backgroundColor: TeknoyTheme.error,
          ),
        );
        return;
      }
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Campus Vendor Honor Code & Privacy Consent to proceed.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(sellerVerificationServiceProvider);
      final submitted = await service.submitVerification(
        userId: widget.userId,
        sellerType: _sellerType,
        officerName: _sellerType == 'ORG' ? _officerNameController.text.trim() : null,
        officerPosition: _sellerType == 'ORG' ? _officerPositionController.text.trim() : null,
        idCardFile: _idCardFile!,
        selfieFile: _selfieFile!,
      );

      if (mounted) {
        setState(() {
          _existingVerification = submitted;
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification documents submitted successfully for administrative review.'),
            backgroundColor: TeknoyTheme.citMaroon,
          ),
        );

        widget.onVerificationSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: TeknoyTheme.error,
          ),
        );
      }
    }
  }

  void _showHonorCodeBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF18181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: TeknoyTheme.citMaroon, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Campus Vendor Agreement',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAgreementItem(
                Icons.verified_outlined,
                'Prohibited Goods Policy',
                'Listing illicit items, weapons, tobacco/vape products, leaked exam keys, or non-academic unauthorized services is strictly forbidden.',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildAgreementItem(
                Icons.location_on_outlined,
                'Safe Campus Handover',
                'All transaction handovers and peer exchanges must occur within designated public CIT-U campus zones (e.g. Canteen, SAL Lobby, Library, Gate 1).',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildAgreementItem(
                Icons.privacy_tip_outlined,
                'Zero-Retention Privacy (RA 10173)',
                'Your identification and biometric selfie are used exclusively for verification and are wiped from server storage once approved or rejected.',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildAgreementItem(
                Icons.school_outlined,
                'Student Handbook Enforcement',
                'Fraudulent behavior or willful misrepresentation of items will result in immediate shop termination and disciplinary referral.',
                isDark,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('I Understand', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgreementItem(IconData icon, String title, String body, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: TeknoyTheme.citGold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB);

    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
        ),
      );
    }

    // ── CASE 1: Pending Admin Verification State
    if (_existingVerification != null && _existingVerification!.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TeknoyTheme.citGold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: TeknoyTheme.citGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Under Review',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your campus seller credentials and biometric selfie have been securely submitted to the University Moderation Hub.\nOnce verified by an administrator, your seller tools will activate automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: TeknoyTheme.citMaroon),
                  const SizedBox(width: 8),
                  Text(
                    'Zero-Retention KYC: Photos will be purged upon decision.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () async {
                await _fetchVerificationHistory();
                widget.onRefreshStatus?.call();
              },
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text(
                'Refresh Review Status',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: TeknoyTheme.citMaroon,
                side: const BorderSide(color: TeknoyTheme.citMaroon),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // ── CASE 2: Inline KYC Form (First time or Resubmission)
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: TeknoyTheme.citMaroon,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Seller Verification',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verify student status to start listing items',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Rejection Banner (if previously rejected)
            if (_existingVerification != null && _existingVerification!.isRejected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resubmission Required',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _existingVerification!.rejectionReason?.isNotEmpty == true
                                ? _existingVerification!.rejectionReason!
                                : 'Previous submission was declined. Please re-capture clearer photos under adequate lighting.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Card 1: CIT Student ID
            _buildPhotoPickerCard(
              title: '1. CIT Student ID Card (Front)',
              subtitle: 'Ensure your Student ID number, full name, and card photo are clearly legible.',
              icon: Icons.badge_outlined,
              selectedFile: _idCardFile,
              isIdCard: true,
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
            ),

            const SizedBox(height: 16),

            // Card 2: Selfie Holding CIT ID
            _buildPhotoPickerCard(
              title: '2. Selfie Holding CIT ID Card',
              subtitle: 'Hold your physical card chest-high beside your face to confirm identity.',
              icon: Icons.face_retouching_natural_rounded,
              selectedFile: _selfieFile,
              isIdCard: false,
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
            ),

            // Organization Lead Officer Fields
            if (_sellerType == 'ORG') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 18, color: TeknoyTheme.citMaroon),
                        const SizedBox(width: 8),
                        Text(
                          'Lead Officer Custodian (Shopee Model)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Designate the student officer holding organizational responsibility for this store.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _officerNameController,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Lead Officer Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _officerPositionController,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Officer Position (e.g. President, Treasurer)',
                        prefixIcon: const Icon(Icons.work_outline_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Campus Vendor Honor Code & Agreement Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, size: 18, color: TeknoyTheme.citGold),
                      const SizedBox(width: 8),
                      Text(
                        'CIT-U Campus Vendor Honor Code',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMicroCommitment(Icons.verified_outlined, 'Honest condition descriptions; zero prohibited goods', isDark),
                  const SizedBox(height: 6),
                  _buildMicroCommitment(Icons.location_on_outlined, 'Peer exchanges inside designated CIT-U campus grounds', isDark),
                  const SizedBox(height: 6),
                  _buildMicroCommitment(Icons.privacy_tip_outlined, 'Zero-Retention: ID and selfie wiped from storage upon review', isDark),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _showHonorCodeBottomSheet(context, isDark),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Read Complete Vendor Terms & Guidelines',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: TeknoyTheme.citMaroon,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  GestureDetector(
                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                            activeColor: TeknoyTheme.citMaroon,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'I have read and agree to the Campus Vendor Honor Code and Privacy Consent.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitVerification,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Uploading Documents...' : 'Submit Verification for Review',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: TeknoyTheme.citMaroon.withOpacity(0.4),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroCommitment(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPickerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required XFile? selectedFile,
    required bool isIdCard,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final hasFile = selectedFile != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile ? const Color(0xFF10B981) : cardBorder,
          width: hasFile ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: hasFile ? const Color(0xFF10B981) : TeknoyTheme.citMaroon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (hasFile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'Attached',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Preview or Action Buttons
          if (hasFile) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 140,
                width: double.infinity,
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                child: FutureBuilder<Uint8List>(
                  future: selectedFile.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon));
                    }
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 140,
                      );
                    }
                    return const Center(child: Icon(Icons.broken_image_outlined, size: 30));
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.camera),
                  icon: const Icon(Icons.cached_rounded, size: 16),
                  label: const Text('Retake with Camera', style: TextStyle(fontFamily: 'Inter', fontSize: 11.5)),
                  style: TextButton.styleFrom(foregroundColor: TeknoyTheme.citMaroon),
                ),
                TextButton.icon(
                  onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Choose File', style: TextStyle(fontFamily: 'Inter', fontSize: 11.5)),
                  style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(
                      isIdCard ? 'Open Camera' : 'Take Live Selfie',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TeknoyTheme.citMaroon,
                      side: const BorderSide(color: TeknoyTheme.citMaroon),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text(
                      'From Gallery',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
