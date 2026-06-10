import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'main.dart';

/// Tracks user inactivity and auto-signs out after 5 minutes of no touch.
class InactivityService with WidgetsBindingObserver {
  static final InactivityService _instance = InactivityService._internal();
  factory InactivityService() => _instance;
  InactivityService._internal();

  static const Duration _timeout = Duration(minutes: 5);
  Timer? _timer;
  bool _isActive = false;

  void start() {
    if (_isActive) return;
    _isActive = true;
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  void stop() {
    if (!_isActive) return;
    _isActive = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void onUserActivity() {
    if (_isActive) _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    if (!_isActive) return;
    stop();
    await authService.signOut(forceNavigateHome: true);
    await Future.delayed(const Duration(milliseconds: 350));
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_off_rounded, color: Color(0xFF3B82F6), size: 36),
                ),
                const SizedBox(height: 18),
                Text('Session Expired',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 10),
                Text('You were automatically signed out\nafter 5 minutes of inactivity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('OK',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && _isActive) {
      _resetTimer();
    }
  }
}

final inactivityService = InactivityService();
