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
  final int initialStep;

  const SellerKYCVerificationView({
    super.key,
    required this.userId,
    this.initialSellerType = 'STUDENT',
    this.onVerificationSubmitted,
    this.onRefreshStatus,
    this.embedded = true,
    this.initialStep = 0,
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

  static final Map<String, SellerVerification?> _cachedVerificationMap = {};

  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;

  SellerVerification? _existingVerification;
  late String _sellerType;
  late final PageController _pageController;
  int _currentStep = 0; // 0: Intro, 1: ID Card, 2: Selfie (+ Org), 3: Review & Honor Code

  @override
  void initState() {
    super.initState();
    _sellerType = widget.initialSellerType;
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
    _fetchVerificationHistory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _officerNameController.dispose();
    _officerPositionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _fetchVerificationHistory({bool forceRefresh = false}) async {
    // Instantaneous 0ms load from memory cache
    if (!forceRefresh && _cachedVerificationMap.containsKey(widget.userId)) {
      final cached = _cachedVerificationMap[widget.userId];
      setState(() {
        _existingVerification = cached;
        if (cached != null) {
          _sellerType = cached.sellerType;
          if (cached.officerName != null) {
            _officerNameController.text = cached.officerName!;
          }
          if (cached.officerPosition != null) {
            _officerPositionController.text = cached.officerPosition!;
          }
        }
        _isLoadingHistory = false;
      });
      if (cached != null && cached.isApproved) {
        widget.onRefreshStatus?.call();
      }
      return;
    }

    setState(() => _isLoadingHistory = _existingVerification == null);
    final service = ref.read(sellerVerificationServiceProvider);
    final record = await service.getLatestVerification(widget.userId);
    _cachedVerificationMap[widget.userId] = record;
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
      if (record != null && record.isApproved) {
        widget.onRefreshStatus?.call();
      }
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
        _cachedVerificationMap[widget.userId] = submitted;
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
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF18181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.gavel_rounded, color: TeknoyTheme.citMaroon, size: 20),
                    ),
                    const SizedBox(width: 12),
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
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildAgreementItem(
                          Icons.verified_outlined,
                          'Prohibited Goods Policy',
                          'Listing illicit items, weapons, tobacco/vape products, leaked exam keys, or non-academic unauthorized services is strictly forbidden.',
                          isDark,
                        ),
                        const SizedBox(height: 14),
                        _buildAgreementItem(
                          Icons.location_on_outlined,
                          'Safe Campus Handover',
                          'All transaction handovers and peer exchanges must occur within designated public CIT-U campus zones (e.g. Canteen, SAL Lobby, Library, Gate 1).',
                          isDark,
                        ),
                        const SizedBox(height: 14),
                        _buildAgreementItem(
                          Icons.privacy_tip_outlined,
                          'Zero-Retention Privacy (RA 10173)',
                          'Your identification and biometric selfie are used exclusively for verification and are wiped from server storage once approved or rejected.',
                          isDark,
                        ),
                        const SizedBox(height: 14),
                        _buildAgreementItem(
                          Icons.school_outlined,
                          'Student Handbook Enforcement',
                          'Fraudulent behavior or willful misrepresentation of items will result in immediate shop termination and disciplinary referral.',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
          ),
        );
      },
    );
  }

  Widget _buildAgreementItem(IconData icon, String title, String body, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: TeknoyTheme.citGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: TeknoyTheme.citGold.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: TeknoyTheme.citGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
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

    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
        ),
      );
    }

    // ── CASE 0: Approved Seller Verification State
    if (_existingVerification != null && _existingVerification!.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 56,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Seller Account Approved',
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
              'Your campus vendor credentials have been approved by the University Moderation Hub.\nYou can now list products and manage your student store.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                widget.onRefreshStatus?.call();
              },
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                'Open Seller Hub',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
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
                color: TeknoyTheme.citGold.withValues(alpha: 0.12),
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
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB)),
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

    // ── CASE 2: Multi-Step Guided Verification Wizard (Step 0 to Step 3)
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          _previousStep();
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top Stepper Indicator (shown on steps 1, 2, 3)
            if (_currentStep > 0) _buildWizardHeader(isDark),

            // Wizard Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Only navigate via Next/Back buttons
                children: [
                  _buildIntroStep(isDark),
                  _buildIdCardStep(isDark),
                  _buildSelfieStep(isDark),
                  _buildReviewAndSubmitStep(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIZARD STEP HEADER & PROGRESS BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildWizardHeader(bool isDark) {
    final stepLabels = ['Student ID', 'ID Selfie', 'Review & Agreement'];
    final activeIndex = _currentStep - 1; // 0, 1, 2

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step $_currentStep of 3: ${stepLabels[activeIndex]}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Campus Seller Verification',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3-Segment Progress Bar
          Row(
            children: List.generate(3, (index) {
              final isCompleted = index < activeIndex;
              final isCurrent = index == activeIndex;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? TeknoyTheme.citMaroon
                        : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 0: VALUE PROPOSITION & ONBOARDING ("WHY BECOME A SELLER")
  // ─────────────────────────────────────────────────────────────
  Widget _buildIntroStep(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1A20) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rejection Banner (if previously rejected)
          if (_existingVerification != null && _existingVerification!.isRejected) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
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

          // Hero Icon & Headline
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.storefront_rounded,
                size: 34,
                color: TeknoyTheme.citMaroon,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Become a Campus Vendor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Turn your textbooks, uniforms, tech gear, and school supplies into cash right here on campus.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Benefits List
          _buildBenefitRow(
            icon: Icons.school_rounded,
            iconColor: TeknoyTheme.citGold,
            title: '100% Student-Only Community',
            desc: 'Every buyer and seller is verified with their CIT-U Student ID. Zero random strangers.',
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            icon: Icons.savings_outlined,
            iconColor: const Color(0xFF10B981),
            title: 'Zero Commission Fees',
            desc: 'You keep 100% of your earnings. No listing fees, no middleman cuts.',
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            icon: Icons.location_on_outlined,
            iconColor: TeknoyTheme.citMaroon,
            title: 'Safe Campus Meetups',
            desc: 'Meet fellow Wildcats during breaks at the Canteen, SAL Lobby, or Library Gate.',
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),
          const SizedBox(height: 12),
          _buildBenefitRow(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: 'Zero-Retention Privacy (RA 10173)',
            desc: 'Your ID and verification selfie are strictly wiped from storage once reviewed.',
            isDark: isDark,
            cardBg: cardBg,
            cardBorder: cardBorder,
          ),

          const SizedBox(height: 32),

          // Big "Apply to Become a Seller" CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start Seller Application',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 1: CIT STUDENT ID CARD (FRONT)
  // ─────────────────────────────────────────────────────────────
  Widget _buildIdCardStep(bool isDark) {
    final hasFile = _idCardFile != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. CIT Student ID Card (Front)',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ensure your Student ID number, full name, and card photo are clearly legible.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Interactive Upload Dropzone Card
          _buildInteractiveDropzone(
            title: 'Front of CIT Student ID',
            subtitle: 'Place card on a flat surface under good lighting',
            icon: Icons.badge_outlined,
            file: _idCardFile,
            isIdCard: true,
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Guidelines Checklist
          _buildChecklistGuideline('Ensure all 4 corners of the ID card are visible.', isDark),
          const SizedBox(height: 6),
          _buildChecklistGuideline('Avoid reflections or camera flash glares.', isDark),
          const SizedBox(height: 6),
          _buildChecklistGuideline('ID number and full name must match your profile.', isDark),

          const SizedBox(height: 32),

          // Next Step Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: hasFile ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                disabledBackgroundColor: (isDark ? Colors.white12 : Colors.black12),
                disabledForegroundColor: (isDark ? Colors.white38 : Colors.black38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasFile ? 'Continue to Selfie' : 'Attach ID Card to Continue',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 2: BIOMETRIC SELFIE HOLDING ID CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildSelfieStep(bool isDark) {
    final hasFile = _selfieFile != null;
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Selfie Holding CIT ID Card',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hold your physical card chest-high beside your face to confirm identity.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Interactive Upload Dropzone Card
          _buildInteractiveDropzone(
            title: 'Live Selfie Holding ID',
            subtitle: 'Hold ID card beside your face in frame',
            icon: Icons.face_retouching_natural_rounded,
            file: _selfieFile,
            isIdCard: false,
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Guidelines Checklist
          _buildChecklistGuideline('Hold physical card chest-high next to your face.', isDark),
          const SizedBox(height: 6),
          _buildChecklistGuideline('Do not obscure your face with hats, glasses, or masks.', isDark),
          const SizedBox(height: 6),
          _buildChecklistGuideline('Both face and card information must be in clear focus.', isDark),

          // Organization Fields if sellerType is ORG
          if (_sellerType == 'ORG') ...[
            const SizedBox(height: 24),
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

          const SizedBox(height: 32),

          // Next Step Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: hasFile ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                disabledBackgroundColor: (isDark ? Colors.white12 : Colors.black12),
                disabledForegroundColor: (isDark ? Colors.white38 : Colors.black38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasFile ? 'Continue to Final Review' : 'Take Selfie to Continue',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STEP 3: REVIEW DOCUMENTS & HONOR CODE AGREEMENT
  // ─────────────────────────────────────────────────────────────
  Widget _buildReviewAndSubmitStep(bool isDark) {
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Review & Honor Code Agreement',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm your submitted documents and accept the campus vendor code.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 18),

          // Uploaded Documents Summary
          Text(
            'Attached Verification Documents',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDocumentReviewPill(
                  title: 'Student ID',
                  file: _idCardFile,
                  onTapChange: () {
                    setState(() => _currentStep = 1);
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDocumentReviewPill(
                  title: 'Selfie with ID',
                  file: _selfieFile,
                  onTapChange: () {
                    setState(() => _currentStep = 2);
                    _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  isDark: isDark,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
              ),
            ],
          ),

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

          // Final Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_isSubmitting || !_agreedToTerms) ? null : _submitVerification,
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
                disabledBackgroundColor: (isDark ? Colors.white12 : Colors.black12),
                disabledForegroundColor: (isDark ? Colors.white38 : Colors.black38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE INTERACTIVE UPLOAD DROPZONE
  // ─────────────────────────────────────────────────────────────
  Widget _buildInteractiveDropzone({
    required String title,
    required String subtitle,
    required IconData icon,
    required XFile? file,
    required bool isIdCard,
    required bool isDark,
  }) {
    final hasFile = file != null;
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282830) : const Color(0xFFE5E7EB);

    if (hasFile) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: FutureBuilder<Uint8List>(
                    future: file.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon));
                      }
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                        );
                      }
                      return const Center(child: Icon(Icons.broken_image_outlined, size: 30));
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Attached',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Retake Photo', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TeknoyTheme.citMaroon,
                        side: const BorderSide(color: TeknoyTheme.citMaroon),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('From Gallery', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(color: cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Empty Dropzone
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TeknoyTheme.citMaroon.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 30, color: TeknoyTheme.citMaroon),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(isIdCard: isIdCard, source: ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    isIdCard ? 'Open Camera' : 'Take Live Selfie',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
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
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentReviewPill({
    required String title,
    required XFile? file,
    required VoidCallback onTapChange,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: file != null
                  ? FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                        }
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                    )
                  : Container(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 24),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onTapChange,
                child: const Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistGuideline(String text, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMicroCommitment(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

