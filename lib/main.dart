import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/services/deep_link_service.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/providers/theme_provider.dart';
import 'package:teknoycart/core/widgets/responsive_frame.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/splash/splash_view.dart';

void main() async {
  // Ensure Flutter engine is ready before calling any platform plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Global crash boundary: catches unhandled asynchronous exceptions to prevent release APK crash
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT_GLOBAL_ERROR: $error\n$stack');
    return true; // Handled, prevents sudden process termination
  };

  // Replaces the release-mode grey screen of death with an isolated recovery fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: TeknoyTheme.citGold, size: 32),
              SizedBox(height: 8),
              Text(
                'Something went wrong displaying this section.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    // Initialize Supabase connection
    await SupabaseConfig.initialize();
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AuthService.passwordRecoveryPending = true;
      }
    });

    runApp(
      const ProviderScope(
        child: TeknoyCartApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('STARTUP_ERROR: $error\n$stackTrace');
    runApp(
      TeknoyStartupErrorApp(error: error),
    );
  }
}

// Global navigator key for post-splash auth state routing
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Custom scroll behavior to enable drag-to-scroll using mouse and trackpad on web/desktop
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class TeknoyCartApp extends ConsumerWidget {
  const TeknoyCartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deepLinkService = ref.watch(deepLinkServiceProvider);
    deepLinkService.initialize();

    ref.listen<bool>(isSplashCompletedProvider, (previous, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          deepLinkService.flushPending();
        });
      }
    });

    // Listen for auth state transitions after the cold-start splash has completed
    ref.listen<AsyncValue<Profile?>>(authStateProvider, (previous, next) {
      if (!ref.read(isSplashCompletedProvider)) return;

      final prevUser = previous?.valueOrNull;
      final nextUser = next.valueOrNull;

      if (prevUser == null && nextUser != null) {
        // User logged in: route to main discovery feed
        appNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProductDiscoveryFeedView()),
          (route) => false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          deepLinkService.flushPending();
        });
      } else if (prevUser != null && nextUser == null) {
        // User logged out: return cleanly to auth gate
        appNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGateView()),
          (route) => false,
        );
      }
    });

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'TeknoyCart',
      debugShowCheckedModeBanner: false,
      theme: TeknoyTheme.lightTheme,
      darkTheme: TeknoyTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      scrollBehavior: AppScrollBehavior(), // Inject drag scroll behavior
      builder: (context, child) {
        return InactivityWrapper(
          onTimeout: () async {
            final user = ref.read(authStateProvider).valueOrNull;
            if (user != null) {
              try {
                await ref.read(authNotifierProvider.notifier).logout();
              } catch (e) {
                debugPrint('INACTIVITY_LOGOUT: $e');
              }
            }
          },
          child: ResponsiveMobileFrame(child: child!),
        );
      },
      home: const SplashView(),
    );
  }
}

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;

  const InactivityWrapper({
    super.key,
    required this.child,
    required this.onTimeout,
  });

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;
  DateTime _lastReset = DateTime.now();

  /// Throttled reset: at most once per 30 seconds to avoid GC pressure
  /// from hundreds of Timer cancels/creates during scroll gestures (HIGH-08)
  static const _throttleDuration = Duration(seconds: 30);

  void _resetTimer() {
    final now = DateTime.now();
    if (now.difference(_lastReset) < _throttleDuration) return;
    _lastReset = now;
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 30), widget.onTimeout);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(minutes: 30), widget.onTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}

/// Fallback presentation when compile-time flags or initialization fails.
/// Prevents the silent blank white screen on Flutter Web and provides actionable run commands.
class TeknoyStartupErrorApp extends StatelessWidget {
  final Object error;

  const TeknoyStartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TeknoyCart - Configuration Required',
      theme: TeknoyTheme.darkTheme,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D0F),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: TeknoyTheme.citGold,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Configuration Required',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFFD1D1D6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'How to run TeknoyCart:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121214),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2C2C2E)),
                      ),
                      child: const SelectableText(
                        'flutter run -d edge --dart-define-from-file=.env.json',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: TeknoyTheme.citGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Or in VS Code:\n1. Open Run & Debug (Ctrl+Shift+D)\n2. Select "TeknoyCart - Edge"\n3. Press F5',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
