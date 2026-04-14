import 'package:flutter/material.dart';
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
import 'email_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash animation
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

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
      
      // STRICT CHECK: If email not verified, force to verification screen
      if (updatedUser != null && !authService.isEmailVerified) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(updatedUser.uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data()!;
            final roleStr = data['role'] ?? 'tenant';
            UserRole userRole = roleStr == 'landlord' ? UserRole.landlord : (roleStr == 'admin' ? UserRole.admin : UserRole.tenant);

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(
                  email: updatedUser.email ?? '',
                  name: data['name'] ?? 'User',
                  selectedRole: userRole,
                ),
              ),
            );
            return;
          }
        } catch (e) {
          print('Error checking unverified user details: $e');
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0FDFA),
              Color(0xFFECFEFF),
              Color(0xFFE0F2FE),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // App Logo
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2DD4BF).withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/images/home237_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 8),

            // Tagline
            const Text(
              'Find and list homes with ease',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),

            const Spacer(flex: 3),

            // Loading Indicator
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
              ),
            ),

            const SizedBox(height: 12),

            // Loading Text
            const Text(
              'L O A D I N G',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}