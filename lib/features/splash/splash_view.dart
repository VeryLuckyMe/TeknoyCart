import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/brand.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../auth/views/auth_gate_view.dart';
import '../auth/views/widgets/auth_form_fields.dart';
import '../feed/views/product_discovery_feed_view.dart';
import 'iris_reveal_route.dart';
import 'teknoy_cart_logo_painter.dart';

/// Global provider indicating when the cold-start splash animation has finished its route reveal.
final isSplashCompletedProvider = StateProvider<bool>((ref) => false);

/// State-of-the-art cold-start splash screen for TeknoyCart.
/// Orchestrates an 8-step assembly and in-place settle animation with 60-120 FPS performance:
/// 1. Blank Start (0 – 150ms)
/// 2. Cart Flash-In with brake tilt (150 – 600ms)
/// 3. Isometric Box Drop & Bounce (600 – 980ms)
/// 4. Hardcover Book Drop & Bounce (980 – 1360ms)
/// 5. Gear 1 Drop (1360 – 1680ms)
/// 6a. Gear 1 Spin + Gear 2 Drop (1680 – 2120ms)
/// 6b. Both Gears Spin Together (2120 – 2520ms)
/// 7. Zoom Out & Brand Reveal (2520 – 3200ms)
/// 8. Seamless In-Place Settle into Login (3200 – 4050ms)
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with TickerProviderStateMixin {
  // Animation Controllers
  late final AnimationController _assemblyController;
  late final AnimationController _settleController;
  late final AnimationController _exitController;

  // Assembly Step Animations (0.0 – 1.0 on _assemblyController, 3200ms)
  late final Animation<double> _cartSlideX;
  late final Animation<double> _cartTilt;
  late final Animation<double> _boxDropY;
  late final Animation<double> _boxOpacity;
  late final Animation<double> _bookDropY;
  late final Animation<double> _bookOpacity;
  late final Animation<double> _gear1DropY;
  late final Animation<double> _gear1Opacity;
  late final Animation<double> _gear1TurnFirst;
  late final Animation<double> _gear2DropY;
  late final Animation<double> _gear2Opacity;
  late final Animation<double> _bothGearsTurnSecond;
  late final Animation<double> _logoScale;
  late final Animation<double> _medallionProgress;
  late final Animation<double> _textProgress;

  // Settle Phase (Step 8: 850ms on _settleController)
  late final Animation<double> _settleCurve;

  // Exit Phase (Iris Reveal for Logged-In Users)
  late final Animation<double> _exitLogoScale;
  late final Animation<double> _exitLogoOpacity;

  // Measurement and layout keys
  final GlobalKey _medallionKey = GlobalKey();
  final GlobalKey _scaffoldKey = GlobalKey();
  double _travelY = 246.0;

  // State Tracking
  bool _hasNavigated = false;
  bool _isSettling = false;
  Offset _capturedLogoCenter = Offset.zero;

  // Dummy controllers for pixel-perfect card preview
  final TextEditingController _dummyEmail = TextEditingController();
  final TextEditingController _dummyPass = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initAnimations();

    // Dynamically measure the exact sub-pixel distance between screen center and resting medallion center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final medallionBox = _medallionKey.currentContext?.findRenderObject() as RenderBox?;
      final scaffoldBox = _scaffoldKey.currentContext?.findRenderObject() as RenderBox?;
      if (medallionBox != null && scaffoldBox != null && medallionBox.hasSize && scaffoldBox.hasSize) {
        final medallionCenter = medallionBox.localToGlobal(
          medallionBox.size.center(Offset.zero),
          ancestor: scaffoldBox,
        );
        final screenCenter = scaffoldBox.size.center(Offset.zero);
        final diff = screenCenter.dy - medallionCenter.dy;
        if (diff > 0) {
          setState(() {
            _travelY = diff;
          });
        }
      }
    });

    _startOrchestration();
  }

  void _initControllers() {
    // 1500ms total for Steps 1–7 assembly (tuned for crisp, snappy motion budget)
    _assemblyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 450ms for Step 8: In-place settle to AuthGateView
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // 450ms for Iris Reveal exit on logged-in path
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  void _initAnimations() {
    // ── Step 2: Empty Cart smoothly slides in from left (0.04 – 0.20) ──
    _cartSlideX = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.04, 0.20, curve: Curves.easeOutCubic),
      ),
    );

    // Subtle forward brake tilt when cart decelerates to a stop
    _cartTilt = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 40),
    ]).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.12, 0.22, curve: Curves.easeOut),
      ),
    );

    // ── Step 3: Isometric Box drops & bounces into cart (0.19 – 0.31) ──
    _boxDropY = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.19, 0.31, curve: Curves.bounceOut),
      ),
    );
    _boxOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.19, 0.23, curve: Curves.easeIn),
      ),
    );

    // ── Step 4: Tilted Book drops & bounces into cart (0.31 – 0.43) ──
    _bookDropY = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.31, 0.43, curve: Curves.bounceOut),
      ),
    );
    _bookOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.31, 0.35, curve: Curves.easeIn),
      ),
    );

    // ── Step 5: Gear 1 drops into position (0.43 – 0.53) ──
    _gear1DropY = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.43, 0.53, curve: Curves.easeOutBack),
      ),
    );
    _gear1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.43, 0.47, curve: Curves.easeIn),
      ),
    );

    // ── Step 6a: Gear 1 turns 1x right while Gear 2 drops (0.53 – 0.67) ──
    _gear1TurnFirst = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.53, 0.67, curve: Curves.easeInOutCubic),
      ),
    );
    _gear2DropY = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.53, 0.67, curve: Curves.easeOutBack),
      ),
    );
    _gear2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.53, 0.57, curve: Curves.easeIn),
      ),
    );

    // ── Step 6b: Both gears turn 1x right together (0.67 – 0.79) ──
    _bothGearsTurnSecond = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.67, 0.79, curve: Curves.easeInOutCubic),
      ),
    );

    // ── Step 7: Slow zoom out into medallion + brand reveal (0.79 – 1.00) ──
    // Scales from 1.0 (140px) down to 32/140 (~0.2286, exactly 32px to match TeknoyLogoImage)
    _logoScale = Tween<double>(begin: 1.0, end: 32.0 / 140.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.79, 0.98, curve: Curves.easeInOutCubic),
      ),
    );
    _medallionProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.81, 0.98, curve: Curves.easeOutCubic),
      ),
    );
    _textProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _assemblyController,
        curve: const Interval(0.84, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    // ── Step 8: Settle Curve (easeInOutCubic for organic arrival) ──
    _settleCurve = CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeInOutCubic,
    );

    // ── Exit Phase (Logged-in Iris Reveal) ──
    _exitLogoScale = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOutCubic),
      ),
    );
    _exitLogoOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _startOrchestration() async {
    // Accessibility reduced motion check
    final disableAnimations = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (disableAnimations) {
      await Future.delayed(const Duration(milliseconds: 200));
      _finishNavigationDirectly();
      return;
    }

    // Check user session immediately for authenticated fast-path
    final session = SupabaseConfig.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (isLoggedIn) {
      // ── LOGGED-IN FAST-PATH: Jump assembly to final state and execute Iris Reveal (zero waiting) ──
      _assemblyController.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;

      final renderBox = _medallionKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        _capturedLogoCenter = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      }
      _exitController.forward();
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted || _hasNavigated) return;
      _executeIrisNavigation();
      return;
    }

    // ── LOGGED-OUT: Snappy 1.5s vector assembly + in-place settle into AuthGate ──
    await _assemblyController.forward();
    if (!mounted) return;

    setState(() {
      _isSettling = true;
    });
    await _settleController.forward();
    if (!mounted || _hasNavigated) return;
    _executeAuthHandover();
  }

  void _finishNavigationDirectly() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    ref.read(isSplashCompletedProvider.notifier).state = true;

    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProductDiscoveryFeedView()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGateView()),
      );
    }
  }

  void _executeIrisNavigation() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    ref.read(isSplashCompletedProvider.notifier).state = true;

    Navigator.of(context).pushReplacement(
      IrisRevealRoute(
        destination: const ProductDiscoveryFeedView(),
        originCenter: _capturedLogoCenter,
        revealDuration: const Duration(milliseconds: 640),
      ),
    );
  }

  void _executeAuthHandover() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    ref.read(isSplashCompletedProvider.notifier).state = true;

    // Seamless zero-duration replacement: AuthGateView is already at matching coordinates
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => const AuthGateView(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _dummyEmail.dispose();
    _dummyPass.dispose();
    _assemblyController.dispose();
    _settleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors exactly matching AuthGateView
    final Color splashBg = isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF8F5F5);
    final Color loginBg = isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF2F2F7);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF8E8E93);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: splashBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _assemblyController,
          _settleController,
          _exitController,
        ]),
        builder: (context, _) {
          // Step 1: Blank canvas (0.00 – 0.05)
          if (_assemblyController.value < 0.05) {
            return Container(color: splashBg);
          }

          final settleVal = _isSettling ? _settleCurve.value : 0.0;
          final currentBg = Color.lerp(splashBg, loginBg, settleVal)!;

          // Basket impact bounces when box and book land
          final double boxBounce = (_assemblyController.value >= 0.25 && _assemblyController.value <= 0.31)
              ? math.sin((_assemblyController.value - 0.25) / 0.06 * math.pi) * 0.4
              : 0.0;
          final double bookBounce = (_assemblyController.value >= 0.37 && _assemblyController.value <= 0.43)
              ? math.sin((_assemblyController.value - 0.37) / 0.06 * math.pi) * 0.4
              : 0.0;

          // Vertical travel offset:
          // At settleVal == 0.0, header is translated down by _travelY to sit in the exact screen center.
          // At settleVal == 1.0, header offset is 0.0, sitting in its natural resting position.
          final double headerOffsetY = (1.0 - settleVal) * _travelY;

          // Card slide & fade: slides up by 50px as it fades in
          final double cardOffsetY = (1.0 - settleVal) * 50.0;
          final double cardOpacity = settleVal.clamp(0.0, 1.0);

          // Exit scale for logged-in path
          final exitScale = _exitController.isAnimating ? _exitLogoScale.value : 1.0;
          final exitOpacity = _exitController.isAnimating ? _exitLogoOpacity.value : 1.0;

          // Crossfade between vector painter and raster logo image during final settle (0.6 - 1.0)
          final double imageCrossfade = ((settleVal - 0.6) / 0.4).clamp(0.0, 1.0);

          return Container(
            color: currentBg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Decorative Circles (smoothly fading in during Step 8) ──
                if (settleVal > 0.005) ...[
                  Positioned(
                    top: -100,
                    right: -80,
                    child: Opacity(
                      opacity: (settleVal * 0.85).clamp(0.0, 1.0),
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.3 : 0.15),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -60,
                    child: Opacity(
                      opacity: (settleVal * 0.85).clamp(0.0, 1.0),
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.2 : 0.12),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Main Content Area (Layout geometrically identical to AuthGateView) ──
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Header (Medallion + Animated Logo + Wordmark + Tagline) ──
                          Transform.translate(
                            offset: Offset(0, headerOffsetY),
                            child: Transform.scale(
                              scale: exitScale,
                              child: Opacity(
                                opacity: exitOpacity.clamp(0.0, 1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Medallion & Logo Stack
                                    SizedBox(
                                      key: _medallionKey,
                                      width: 58,
                                      height: 58,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Circular Medallion Badge (Fades in during Step 7)
                                          Opacity(
                                            opacity: _medallionProgress.value.clamp(0.0, 1.0),
                                            child: Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isDark
                                                    ? const Color(0xFFFFF7F2)
                                                    : TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                                                border: isDark
                                                    ? Border.all(
                                                        color: TeknoyTheme.citGold.withValues(alpha: 0.40),
                                                        width: 1.5,
                                                      )
                                                    : null,
                                                boxShadow: isDark
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.20),
                                                          blurRadius: 10,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ),

                                          // Vector Logo Assembly (140x140 scaling down into 32px logo)
                                          if (imageCrossfade < 1.0)
                                            Opacity(
                                              opacity: (1.0 - imageCrossfade).clamp(0.0, 1.0),
                                              child: OverflowBox(
                                                minWidth: 0,
                                                minHeight: 0,
                                                maxWidth: 300,
                                                maxHeight: 300,
                                                child: Transform.scale(
                                                  scale: _logoScale.value,
                                                  child: SizedBox(
                                                    width: 140,
                                                    height: 140,
                                                    child: CustomPaint(
                                                      painter: TeknoyCartLogoPainter(
                                                        cartSlideX: _cartSlideX.value,
                                                        cartTilt: _cartTilt.value,
                                                        cartBounceY: boxBounce + bookBounce,
                                                        boxDropY: _boxDropY.value,
                                                        boxOpacity: _boxOpacity.value,
                                                        bookDropY: _bookDropY.value,
                                                        bookOpacity: _bookOpacity.value,
                                                        gear1DropY: _gear1DropY.value,
                                                        gear1Opacity: _gear1Opacity.value,
                                                        gear1Angle: (_gear1TurnFirst.value + _bothGearsTurnSecond.value) *
                                                            2 *
                                                            math.pi,
                                                        gear2DropY: _gear2DropY.value,
                                                        gear2Opacity: _gear2Opacity.value,
                                                        gear2Angle: _bothGearsTurnSecond.value * 2 * math.pi,
                                                        primaryColor: TeknoyTheme.citMaroon,
                                                        isDark: isDark,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Clean Raster Logo Image (Crossfades in at resting scale for 100% fidelity)
                                          if (imageCrossfade > 0.0)
                                            Opacity(
                                              opacity: imageCrossfade,
                                              child: const TeknoyLogoImage(size: 32),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Brand Wordmark & Tagline (fade in below medallion during Step 7)
                                    Opacity(
                                      opacity: _textProgress.value.clamp(0.0, 1.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'TEKNOYCART',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: TeknoyTheme.citMaroon,
                                              letterSpacing: 2.0,
                                            ),
                                          ),
                                          Text(
                                            'CIT-U EXCLUSIVE CAMPUS MARKETPLACE',
                                            style: TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: subtitleColor,
                                              letterSpacing: 2.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Login Card & Footer (Slides up in-place during Step 8) ──
                          Transform.translate(
                            offset: Offset(0, cardOffsetY),
                            child: Opacity(
                              opacity: cardOpacity,
                              child: _buildLoginCardPreview(isDark, subtitleColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Exact visual counterpart to AuthGateView's glassmorphic login card.
  /// Always present in the layout hierarchy to guarantee 0ms sub-pixel parity.
  Widget _buildLoginCardPreview(bool isDark, Color subtitleColor) {
    final cardBg = isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E5EA);
    final titleColor = isDark ? Colors.white : const Color(0xFF1D1D1F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to access student deals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Exact AuthInputField preview for Email
                    AuthInputField(
                      controller: _dummyEmail,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Exact AuthInputField preview for Password
                    AuthInputField(
                      controller: _dummyPass,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      enabled: false,
                      suffixIcon: Icon(
                        Icons.visibility_off_outlined,
                        color: isDark ? Colors.white60 : Colors.black54,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          minimumSize: const Size(44, 40),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TeknoyTheme.citGold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login button preview matching AuthLoginForm
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF990000),
                            TeknoyTheme.citMaroon,
                            Color(0xFF660000),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: const Text(
                'Sign up',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TeknoyTheme.citMaroon,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
