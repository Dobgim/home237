import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'auth_service.dart';
import 'tenant_dashboard.dart';
import 'landlord_dashboard.dart';
import 'admin_dashboard.dart';
import 'theme_notifier.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    // Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Pulse glow animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer animation for loading text
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _logoController.forward();
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash animation
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    if (kIsWeb) {
      try {
        await authService.handleRedirectResult();
      } catch (e) {
        debugPrint('Error checking Google redirect result: $e');
      }
    }

    // ── NEW: Check if first launch ─────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }
    // ──────────────────────────────────────────────────────────────────────

    // Check if user is already signed in with Firebase
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // ── NEW: Reload user to get latest verification status ────────────────
      await authService.refreshUserStatus();
      
      final updatedUser = FirebaseAuth.instance.currentUser;
      
      // STRICT CHECK: If email not verified, force them to start over
      if (updatedUser != null && !authService.isEmailVerified) {
        try {
          // If they restart the app unverified, sign them out and show HomePage
          await authService.signOut(forceNavigateHome: false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
          return;
        } catch (e) {
          print('Error handling unverified user on splash: $e');
        }
      }

      // User is signed in and verified, fetch their data from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser?.uid ?? currentUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;

          // Get user role
          final roleStr = data['role'] ?? 'none';
          UserRole userRole = UserRole.none;

          if (roleStr == 'tenant') {
            userRole = UserRole.tenant;
          } else if (roleStr == 'landlord') {
            userRole = UserRole.landlord;
          } else if (roleStr == 'admin') {
            userRole = UserRole.admin;
          } else {
            userRole = UserRole.none;
          }

          // Restore user session in auth service
          authService.restoreSession(
            userId: currentUser.uid,
            userEmail: data['email'] ?? currentUser.email ?? '',
            userName: data['name'] ?? currentUser.email?.split('@')[0] ?? 'User',
            userRole: userRole,
          );

          // ✅ UPDATE THEME FOR THIS USER'S ROLE
          if (mounted) {
            context.read<ThemeNotifier>().updateThemeForRole();
          }

          // Navigate based on role
          if (!mounted) return;

          Widget destination;
          if (userRole == UserRole.tenant) {
            destination = const TenantDashboard();
          } else if (userRole == UserRole.landlord) {
            destination = const LandlordDashboard();
          } else if (userRole == UserRole.admin) {
            destination = const AdminDashboard();
          } else {
            destination = const HomePage();
          }

          print('🔍 DEBUG: Splash - UserRole: $userRole, Navigating to: ${destination.runtimeType}');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
          return;
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    // No user signed in or error occurred, go to home page
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF0D2137),
              Color(0xFF0F2D4D),
              Color(0xFF0A1628),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle background particles / circles
            ..._buildBackgroundOrbs(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Animated logo with glow
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoController, _pulseController]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6)
                                      .withOpacity(0.35 * _pulseAnim.value),
                                  blurRadius: 40 * _pulseAnim.value,
                                  spreadRadius: 5 * _pulseAnim.value,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF06B6D4)
                                      .withOpacity(0.2 * _pulseAnim.value),
                                  blurRadius: 60 * _pulseAnim.value,
                                  spreadRadius: 10 * _pulseAnim.value,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(36),
                              child: Image.asset(
                                'assets/images/new_home237_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // App name with gradient text
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _taglineOpacity.value,
                        child: SlideTransition(
                          position: _taglineSlide,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF60A5FA),
                                Color(0xFF34D399),
                                Color(0xFF60A5FA),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Home237',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _taglineOpacity.value,
                        child: const Text(
                          'Find and list homes with ease',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 3),

                  // Animated loading indicator
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3B82F6)
                                .withOpacity(0.15 + 0.15 * _pulseAnim.value),
                            width: 1.5,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // Shimmer loading text
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Color(0xFF475569),
                              Color(0xFF94A3B8),
                              Color(0xFF475569),
                            ],
                            stops: [
                              (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                              _shimmerAnim.value.clamp(0.0, 1.0),
                              (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'L O A D I N G',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundOrbs() {
    return [
      // Top-right orb
      Positioned(
        top: -60,
        right: -40,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.08 * _pulseAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ),
      // Bottom-left orb
      Positioned(
        bottom: -80,
        left: -60,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withOpacity(0.06 * _pulseAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ),
      // Center subtle glow
      Positioned(
        top: MediaQuery.of(context).size.height * 0.3,
        left: MediaQuery.of(context).size.width * 0.2,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E40AF).withOpacity(0.05 * _pulseAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}