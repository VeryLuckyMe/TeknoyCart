import 'dart:async';

import 'package:flutter/widgets.dart';

/// Signs the user out after [timeout] without interaction (SRS FR-02: 30 min).
///
/// Two paths trigger [onTimeout]:
///  * a foreground timer, reset (throttled) on every pointer-down;
///  * an app-resume check. Dart timers do not run while a phone app is
///    suspended, so without this a user who backgrounds the app for hours
///    would come back still signed in.
class InactivityWrapper extends StatefulWidget {
  const InactivityWrapper({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = defaultTimeout,
    this.clock = DateTime.now,
  });

  static const Duration defaultTimeout = Duration(minutes: 30);

  /// Pointer events within this window of the last reset don't restart the
  /// timer, avoiding hundreds of Timer cancels during a scroll (HIGH-08).
  static const Duration throttle = Duration(seconds: 30);

  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;
  final DateTime Function() clock;

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _lastActivity;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivity = widget.clock();
    _startTimer(widget.timeout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, _fire);
  }

  void _fire() {
    if (_timedOut) return;
    _timedOut = true;
    _timer?.cancel();
    widget.onTimeout();
  }

  void _onActivity() {
    final now = widget.clock();
    if (_timedOut) {
      // New session after a timeout logout: start counting again.
      _timedOut = false;
    } else if (now.difference(_lastActivity) < InactivityWrapper.throttle) {
      return;
    }
    _lastActivity = now;
    _startTimer(widget.timeout);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _timedOut) return;
    final idle = widget.clock().difference(_lastActivity);
    if (idle >= widget.timeout) {
      _fire();
    } else {
      _startTimer(widget.timeout - idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      child: widget.child,
    );
  }
}
