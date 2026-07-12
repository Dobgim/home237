import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'auth_service.dart';
import 'landlord_dashboard.dart';
import 'admin_dashboard.dart';
import 'tenant_dashboard.dart';
import 'theme_notifier.dart';
import 'onboarding_screen.dart';
import 'signin_screen.dart';

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
    if (kIsWeb) {
      // Never let the redirect-result handshake block startup. If it stalls
      // (slow auth iframe, flaky network), time out and proceed — the
      // currentUser check below still routes a signed-in user to their
      // dashboard, so the app can never get stuck on the splash spinner.
      try {
        await authService
            .handleRedirectResult()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Redirect result check skipped/failed: $e');
      }
    }

    // Minimum splash display time. On web we skip the long branded splash so
    // visitors arriving from the marketing site land on sign-in immediately;
    // on mobile it runs concurrently with the auth/data work below.
    final splashTimer = Future.delayed(
        kIsWeb ? Duration.zero : const Duration(milliseconds: 3500));

    // Role passed from the marketing site's picker (?role=tenant|landlord).
    final String? webRole =
        kIsWeb ? Uri.base.queryParameters['role'] : null;

    // Resolve where to navigate while the splash animation plays.
    Widget destination = const HomePage();

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;

      // A signed-in user (including one returning from a Google redirect) must
      // always land on their dashboard — never the onboarding/role screen.
      if (currentUser == null && webRole == null && !hasSeenOnboarding) {
        destination = const OnboardingScreen();
      } else {
        if (currentUser != null) {
          // Reload user to get latest verification status.
          await authService.refreshUserStatus();
          final updatedUser = FirebaseAuth.instance.currentUser;

          if (updatedUser != null && !authService.isEmailVerified) {
            // Unverified — sign them out and show HomePage.
            await authService.signOut(forceNavigateHome: false);
            destination = const HomePage();
          } else {
            // Signed in and verified — fetch their data from Firestore.
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(updatedUser?.uid ?? currentUser.uid)
                .get();

            if (!userDoc.exists) {
              // User document deleted from Firestore — sign out.
              debugPrint('🚨 Splash: User document not found. Signing out.');
              await authService.signOut(forceNavigateHome: false);
              destination = const HomePage();
            } else {
              final data = userDoc.data()!;

              if (data['suspended'] == true) {
                debugPrint('🚨 Splash: User is suspended. Signing out.');
                await authService.signOut(forceNavigateHome: false);
                destination = const HomePage();
              } else {
                final roleStr = data['role'] ?? 'none';
                UserRole userRole = UserRole.none;
                if (roleStr == 'tenant') {
                  userRole = UserRole.tenant;
                } else if (roleStr == 'landlord') {
                  userRole = UserRole.landlord;
                } else if (roleStr == 'admin') {
                  userRole = UserRole.admin;
                }

                authService.restoreSession(
                  userId: currentUser.uid,
                  userEmail: data['email'] ?? currentUser.email ?? '',
                  userName: data['name'] ??
                      currentUser.email?.split('@')[0] ??
                      'User',
                  userRole: userRole,
                );

                if (mounted) {
                  context.read<ThemeNotifier>().updateThemeForRole();
                }

                if (userRole == UserRole.landlord) {
                  destination = const LandlordDashboard(); // agent dashboard
                } else if (userRole == UserRole.admin) {
                  destination = const AdminDashboard();
                } else if (userRole == UserRole.tenant) {
                  destination = const TenantDashboard(); // home-seeker dashboard
                } else {
                  destination = const HomePage(); // guests browse
                }
              }
            }
          }
        } else if (webRole != null) {
          // Logged-out visitor from the marketing site → sign in / sign up,
          // with the chosen role primed for a new account.
          destination = SignInScreen(preselectedRole: _roleFromString(webRole));
        }
      }
    } catch (e) {
      debugPrint('Error resolving startup destination: $e');
      destination = const HomePage();
    }

    // Ensure the splash stayed visible for the full minimum duration.
    await splashTimer;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  UserRole? _roleFromString(String? r) {
    if (r == 'tenant') return UserRole.tenant;
    if (r == 'landlord') return UserRole.landlord;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // No branded splash on web — just a brief neutral loading frame while
      // auth resolves, then straight to the homepage / sign-in.
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 2.6, color: Color(0xFF3B82F6)),
          ),
        ),
      );
    }
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