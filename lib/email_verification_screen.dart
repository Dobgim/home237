import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'auth_service.dart';
import 'tenant_dashboard.dart';
import 'landlord_dashboard.dart';
import 'pending_property_service.dart';
import 'widgets/language_toggle.dart';
import 'property_details_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final UserRole selectedRole;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.selectedRole,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _resendVerificationEmail() async {
    final t = AppLocalizations.of(context);
    if (_secondsRemaining > 0) return;

    setState(() => _isResending = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        
        _startTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                   const Icon(Icons.check_circle, color: Colors.white),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       t.get('verification_email_sent'),
                       style: const TextStyle(fontWeight: FontWeight.w500),
                     ),
                   ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.get('error_sending_email')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isResending = false);
    }
  }

  Future<void> _checkEmailVerified() async {
    final t = AppLocalizations.of(context);
    setState(() => _isChecking = true);

    try {
      // Reload user and force refresh token to get latest status
      await authService.refreshUserStatus();

      if (authService.isEmailVerified) {
        // Email is verified! Update Firestore and proceed
        await _completeSignup(FirebaseAuth.instance.currentUser?.uid ?? '');
      } else {
        // STRICT ENFORCEMENT: Not verified yet
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.white),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       t.get('verification_strict_error'),
                       style: const TextStyle(fontWeight: FontWeight.w500),
                     ),
                   ),
                ],
              ),
              backgroundColor: const Color(0xFFF59E0B), // Professional Orange/Amber
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.get('error_checking_verification')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _completeSignup(String userId) async {
    final t = AppLocalizations.of(context);
    try {
      // Update existing Firestore document
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'emailVerified': true,
        'updatedAt': DateTime.now(),
      });

      // Update auth service state
      authService.restoreSession(
        userId: userId,
        userEmail: widget.email,
        userName: widget.name,
        userRole: widget.selectedRole,
        hasSeenWelcome: false, // NEW: Trigger welcome popup on dashboard
      );

      // Navigate to appropriate dashboard
      if (mounted) {
        Widget destination;
        if (widget.selectedRole == UserRole.tenant) {
          destination = const TenantDashboard();
        } else {
          destination = const LandlordDashboard();
        }

        // Return new user to the property they were viewing before sign-up
        final pending = PendingPropertyService.instance.consume();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );

        if (pending != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(
                propertyId: pending.propertyId,
                propertyData: pending.propertyData,
                autoAction: pending.pendingAction,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.get('error_completing_signup')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox(), // Prevent going back
        actions: const [
          LanguageToggle(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: Color(0xFF3B82F6),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                t.get('verify_title'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                t.get('verify_sent_to'),
                style: TextStyle(
                  fontSize: 16,
                  color: subtitleColor,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
                textAlign: TextAlign.center,
              ),

              // Instructions Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Text(
                          t.get('verify_instructions_title'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStepRow(1, t.get('verify_step_1'), isDark),
                    const SizedBox(height: 12),
                    _buildStepRow(2, t.get('verify_step_2'), isDark),
                    const SizedBox(height: 12),
                    _buildStepRow(3, t.get('verify_step_3'), isDark),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.get('click_link_then_tap'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Verify Button – always pressable; check happens on tap
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkEmailVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          t.get('ive_verified'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Email Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: (_isResending || _secondsRemaining > 0) ? null : _resendVerificationEmail,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: (_isResending || _secondsRemaining > 0)
                          ? (isDark ? Colors.white24 : Colors.black12)
                          : const Color(0xFF3B82F6),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                          ),
                        )
                      : Text(
                          _secondsRemaining > 0
                              ? '${t.get('resend_wait')} 00:${_secondsRemaining.toString().padLeft(2, '0')}'
                              : t.get('resend_link'),
                          style: TextStyle(
                            fontSize: 16,
                            color: (_isResending || _secondsRemaining > 0)
                                ? subtitleColor
                                : const Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}
