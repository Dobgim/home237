import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'signin_screen.dart';
import 'email_verification_screen.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'tenant_dashboard.dart';
import 'landlord_dashboard.dart';
import 'admin_dashboard.dart';
import 'theme_notifier.dart';
import 'widgets/language_toggle.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole? _selectedRole; // Added for role selection

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignUp() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your role (Tenant or Landlord) first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await authService.signInWithGoogle(defaultRole: _selectedRole);
    setState(() => _isLoading = false);

    if (success && mounted) {
      TextInput.finishAutofillContext();
      
      if (authService.isNewUser) {
        // New Google user -> Dashboard (no verification needed for Google)
        context.read<ThemeNotifier>().updateThemeForRole();
        Widget destination;
        if (authService.userRole == UserRole.tenant) {
          destination = TenantDashboard();
        } else if (authService.userRole == UserRole.landlord) {
          destination = LandlordDashboard();
        } else if (authService.userRole == UserRole.admin) {
          destination = AdminDashboard();
        } else {
          destination = HomePage();
        }
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destination),
          (route) => false,
        );
      } else {
        // Existing Google user -> Home
        context.read<ThemeNotifier>().updateThemeForRole();
        Widget destination;
        if (authService.userRole == UserRole.tenant) {
          destination = TenantDashboard();
        } else if (authService.userRole == UserRole.landlord) {
          destination = LandlordDashboard();
        } else if (authService.userRole == UserRole.admin) {
          destination = AdminDashboard();
        } else {
          destination = HomePage();
        }
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destination),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.lastError ?? 'Google Sign-Up failed or canceled.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      // Check if role is selected
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your role (Tenant or Landlord)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Create user account
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Create user document in Firestore immediately
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': _selectedRole!.toString().split('.').last,
            'createdAt': DateTime.now(),
            'emailVerified': false,
            'hasSeenWelcome': false,
            'subscriptionStatus': 'free',
          });
          print('✅ Firestore user document created immediately');
        } catch (dbError) {
          print('❌ Error creating initial Firestore document: $dbError');
        }

        // Send email verification
        try {
          print('📧 Attempting to send verification email to: ${_emailController.text.trim()}');
          await userCredential.user?.sendEmailVerification();
          print('✅ Email verification sent successfully!');
        } catch (emailError) {
          print('❌ Error sending verification email: $emailError');
          // Continue anyway - user can try resend later
        }

        setState(() => _isLoading = false);

        // Navigate to email verification screen
        if (mounted) {
          // Trigger system autofill save/update
          TextInput.finishAutofillContext();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: _emailController.text.trim(),
                name: _nameController.text.trim(),
                selectedRole: _selectedRole!,
              ),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final labelColor = isDark ? Colors.white : const Color(0xFF374151);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inputFill = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final inputBorder = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          LanguageToggle(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // App Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/home237_logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Header
                  Text(
                    t.get('create_account'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to get started with ${t.get('app_name')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: subtitleColor,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Full Name Field
                  Text(
                    t.get('full_name'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    autofillHints: const [AutofillHints.name],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: t.get('full_name_hint'),
                      hintStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.person_outline, color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return t.get('err_name_empty');
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email Field
                  Text(
                    t.get('email'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: t.get('email_hint'),
                      hintStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return t.get('err_email_empty');
                      if (!value.contains('@')) return t.get('err_email_invalid');
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Role Selection
                  Text(
                    t.get('select_role'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: inputBorder),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<UserRole>(
                          title: Text(
                            t.get('tenant'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            t.get('tenant_desc'),
                            style: TextStyle(fontSize: 13, color: subtitleColor),
                          ),
                          value: UserRole.tenant,
                          groupValue: _selectedRole,
                          activeColor: const Color(0xFF3B82F6),
                          onChanged: (value) {
                            setState(() => _selectedRole = value);
                          },
                        ),
                        Divider(height: 1, color: inputBorder),
                        RadioListTile<UserRole>(
                          title: Text(
                            t.get('landlord'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            t.get('landlord_desc'),
                            style: TextStyle(fontSize: 13, color: subtitleColor),
                          ),
                          value: UserRole.landlord,
                          groupValue: _selectedRole,
                          activeColor: const Color(0xFF3B82F6),
                          onChanged: (value) {
                            setState(() => _selectedRole = value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Password Field
                  Text(
                    t.get('password'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: t.get('password_hint'),
                      hintStyle: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white60 : const Color(0xFF9CA3AF)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? Colors.white60 : const Color(0xFF9CA3AF),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return t.get('err_password_empty');
                      if (value.length < 6) return t.get('password_too_short');
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm Password Field
                  Text(
                    t.get('confirm_password'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.password],
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: t.get('confirm_password_hint'),
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t.get('err_confirm_password_empty');
                      }
                      if (value != _passwordController.text) {
                        return t.get('passwords_dont_match');
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        t.get('sign_up'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Continue with Google (Airbnb style) ────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: _isLoading ? null : _handleGoogleSignUp,
                        splashColor: Colors.grey.withOpacity(0.12),
                        highlightColor: Colors.grey.withOpacity(0.06),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFDDDDDD),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Google logo — pinned to left
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF4285F4)),
                                        )
                                      : Image.asset(
                                          'assets/images/google_logo.png',
                                          height: 22,
                                          width: 22,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.account_circle,
                                                  color: Color(0xFF4285F4),
                                                  size: 22),
                                        ),
                                ),
                                // Label — perfectly centered
                                Text(
                                  t.get('continue_with_google'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF222222),
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(height: 24),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${t.get('already_have_account')} ", style: TextStyle(color: subtitleColor)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInScreen()),
                          );
                        },
                        child: Text(
                          t.get('sign_in'),
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    ),
    );
  }
}