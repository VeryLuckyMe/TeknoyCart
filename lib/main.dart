import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/responsive_frame.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

void main() async {
  // Ensure Flutter engine is ready before calling any platform plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase connection
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: TeknoyCartApp(),
    ),
  );
}

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
    final authStateAsync = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'TeknoyCart',
      debugShowCheckedModeBanner: false,
      theme: TeknoyTheme.lightTheme,
      darkTheme: TeknoyTheme.darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: AppScrollBehavior(), // Inject drag scroll behavior
      builder: (context, child) {
        return InactivityWrapper(
          onTimeout: () async {
            final user = ref.read(authStateProvider).valueOrNull;
            if (user != null) {
              try {
                await ref.read(authNotifierProvider.notifier).logout();
              } catch (_) {}
            }
          },
          child: ResponsiveMobileFrame(child: child!),
        );
      },
      home: authStateAsync.when(
        data: (user) {
          if (user != null) {
            return const ProductDiscoveryFeedView();
          }
          return const AuthGateView();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: TeknoyTheme.citMaroon,
            ),
          ),
        ),
        error: (err, _) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Critical Error: $err',
                style: const TextStyle(color: TeknoyTheme.error),
              ),
            ),
          ),
        ),
      ),
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

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 30), widget.onTimeout);
  }

  @override
  void initState() {
    super.initState();
    _resetTimer();
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
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}

