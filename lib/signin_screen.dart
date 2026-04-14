import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'signup_screen.dart';
import 'email_verification_screen.dart';
import 'role_selection_screen.dart';
import 'forgot_password_screen.dart';
import 'widgets/language_toggle.dart';
import 'home_page.dart';
import 'tenant_dashboard.dart';
import 'landlord_dashboard.dart';
import 'admin_dashboard.dart';
import 'theme_notifier.dart';
import 'pending_property_service.dart';
import 'property_details_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      await _saveCredentials();

      try {
        // Sign in with Firebase
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final user = userCredential.user;

        // Check if email is verified
        if (user != null && !authService.isEmailVerified) {
          // Get user data to retrieve role for verification screen
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          setState(() => _isLoading = false);

          if (mounted) {
            String name = 'User';
            UserRole role = UserRole.tenant;

            if (userDoc.exists) {
               name = userDoc.data()?['name'] ?? 'User';
               final roleStr = userDoc.data()?['role'] ?? 'tenant';
               role = roleStr == 'landlord' ? UserRole.landlord : (roleStr == 'admin' ? UserRole.admin : UserRole.tenant);
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(
                  email: user.email ?? '',
                  name: name,
                  selectedRole: role,
                ),
              ),
            );
          }
          return;
        }

        // Proceed with normal signin
        final success = await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

        setState(() => _isLoading = false);

        if (success && mounted) {
          _routeUser();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign in failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _routeUser() {
    TextInput.finishAutofillContext();
    context.read<ThemeNotifier>().updateThemeForRole();
    
    Widget destination;
    
    // New Google user: show role selection FIRST
    if (authService.isNewUser) {
      destination = const RoleSelectionScreen();
    } else if (authService.userRole == UserRole.tenant) {
      destination = TenantDashboard();
    } else if (authService.userRole == UserRole.landlord) {
      destination = LandlordDashboard();
    } else if (authService.userRole == UserRole.admin) {
      destination = AdminDashboard();
    } else {
      destination = HomePage();
    }

    final pending = PendingPropertyService.instance.consume();
    if (pending != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
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
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final success = await authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (success && mounted) {
      _routeUser();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.lastError ?? 'Google Sign-In failed or was canceled.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                  const SizedBox(height: 20),
                  
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

                  const SizedBox(height: 24),

                  Text(
                    t.get('welcome_back'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue to ${t.get('app_name')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: subtitleColor,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Text(t.get('email'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: labelColor)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return t.get('err_email_empty');
                      if (!value.contains('@')) return t.get('err_email_invalid');
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(t.get('password'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: labelColor)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return t.get('err_password_empty');
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(() => _rememberMe = value ?? false),
                              activeColor: const Color(0xFF3B82F6),
                            ),
                            Flexible(
                              child: Text(
                                t.get('remember_me'),
                                style: TextStyle(color: labelColor, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                        child: Text(t.get('forgot_password'), style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : Text(t.get('sign_in'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                        onTap: _isLoading ? null : _handleGoogleSignIn,
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${t.get('dont_have_account')} ", style: TextStyle(color: subtitleColor)),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                        child: Text(t.get('sign_up'), style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
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