import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'app_localizations.dart';
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

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _rememberMe = false;

  late AnimationController _aniCtrl;
  late Animation<double> _fadeAni;
  late Animation<Offset> _slideAni;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _aniCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAni = CurvedAnimation(parent: _aniCtrl, curve: Curves.easeOut);
    _slideAni = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _aniCtrl, curve: Curves.easeOut));
    _aniCtrl.forward();
  }

  @override
  void dispose() {
    _aniCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('remember_me') ?? false) {
        setState(() {
          _emailCtrl.text = prefs.getString('saved_email') ?? '';
          _passCtrl.text = prefs.getString('saved_password') ?? '';
          _rememberMe = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailCtrl.text.trim());
        await prefs.setString('saved_password', _passCtrl.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (_) {}
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await _saveCredentials();
    try {
      UserCredential uc = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);

      // Reload to get the freshest emailVerified flag from Firebase servers
      await uc.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        // Account exists but email is not yet verified — send to verification screen
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        setState(() => _isLoading = false);
        if (mounted) {
          String name = 'User';
          UserRole role = UserRole.tenant;
          if (userDoc.exists) {
            name = userDoc.data()?['name'] ?? 'User';
            final rs = userDoc.data()?['role'] ?? 'tenant';
            role = rs == 'landlord'
                ? UserRole.landlord
                : (rs == 'admin' ? UserRole.admin : UserRole.tenant);
          }
          // Make sure a fresh verification email goes out
          try { await user.sendEmailVerification(); } catch (_) {}
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: user.email ?? '',
              name: name,
              selectedRole: role,
            ),
          ));
        }
        return;
      }

      // Email verified (or Google account) — proceed with full sign-in
      final success = await authService.signIn(
          _emailCtrl.text.trim(), _passCtrl.text);
      setState(() => _isLoading = false);
      if (success && mounted) {
        _routeUser();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authService.lastError ?? 'Invalid email or password'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final message = AppLocalizations.of(context).getAuthErrorMessage(e.code, e.message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final message = AppLocalizations.of(context).get('err_unexpected');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      }
    }
  }

  void _routeUser() {
    TextInput.finishAutofillContext();
    context.read<ThemeNotifier>().updateThemeForRole();
    Widget dest;
    if (authService.isNewUser) {
      dest = const RoleSelectionScreen();
    } else if (authService.userRole == UserRole.tenant) {
      dest = TenantDashboard();
    } else if (authService.userRole == UserRole.landlord) {
      dest = LandlordDashboard();
    } else if (authService.userRole == UserRole.admin) {
      dest = AdminDashboard();
    } else {
      dest = HomePage();
    }
    final pending = PendingPropertyService.instance.consume();
    if (pending != null) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => dest), (r) => false);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailsScreen(
        propertyId: pending.propertyId, propertyData: pending.propertyData, autoAction: pending.pendingAction)));
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => dest), (r) => false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final success = await authService.signInWithGoogle();
    setState(() => _isLoading = false);
    if (success && mounted) {
      _routeUser();
    } else if (mounted && authService.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authService.lastError!),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16)));
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: FadeTransition(
        opacity: _fadeAni,
        child: SlideTransition(
          position: _slideAni,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(isDark, t),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                        blurRadius: 28, offset: const Offset(0, 10))]),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _googleBtn(isDark, t),
                            const SizedBox(height: 22),
                            _divider(isDark, 'or continue with email'),
                            const SizedBox(height: 22),
                            _field(label: t.get('email'), ctrl: _emailCtrl,
                              hint: t.get('email_hint'), icon: Icons.email_outlined,
                              isDark: isDark, keyboard: TextInputType.emailAddress,
                              autofill: AutofillHints.email,
                              validator: (v) {
                                if (v == null || v.isEmpty) return t.get('err_email_empty');
                                if (!v.contains('@')) return t.get('err_email_invalid');
                                return null;
                              }),
                            const SizedBox(height: 16),
                            _passwordField(t, isDark),
                            const SizedBox(height: 8),
                            _rememberRow(t, isDark),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.55),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : Text(t.get('sign_in'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('${t.get('dont_have_account')} ',
                                style: TextStyle(fontSize: 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(context,
                                  MaterialPageRoute(builder: (_) => const SignUpScreen())),
                                child: Text(t.get('sign_up'),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.w700))),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, dynamic t) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36))),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Stack(children: [
            Positioned(top: 0, left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
                onPressed: () => Navigator.pop(context))),
            const Positioned(top: 4, right: 8, child: LanguageToggle()),
            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8))]),
                child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/new_home237_logo.png', fit: BoxFit.cover))),
              const SizedBox(height: 12),
              Text(t.get('welcome_back'),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Sign in to continue to ${t.get('app_name')}',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
            ])),
          ]),
        ),
      ),
    );
  }

  // ── Google Button ────────────────────────────────────────────────────────────
  Widget _googleBtn(bool isDark, dynamic t) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoading ? null : _handleGoogleSignIn,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF222222), width: 1.2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
                : SizedBox(
                    width: 20, height: 20,
                    child: Image.asset('assets/images/google_logo.png', height: 20, width: 20,
                      errorBuilder: (_, __, ___) => CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter())),
                  ),
            const SizedBox(width: 10),
            Text(t.get('continue_with_google'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222), letterSpacing: -0.2)),
          ]),
        ),
      ),
    );
  }

  // ── Divider ──────────────────────────────────────────────────────────────────
  Widget _divider(bool isDark, String label) {
    final dc = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final tc = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Row(children: [
      Expanded(child: Divider(color: dc)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: TextStyle(color: tc, fontSize: 12, fontWeight: FontWeight.w500))),
      Expanded(child: Divider(color: dc)),
    ]);
  }

  // ── Generic Field ─────────────────────────────────────────────────────────────
  Widget _field({required String label, required TextEditingController ctrl,
      required String hint, required IconData icon, required bool isDark,
      TextInputType? keyboard, String? autofill, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, keyboardType: keyboard,
        autofillHints: autofill != null ? [autofill] : null,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
        decoration: _dec(isDark, hint, icon), validator: validator),
    ]);
  }

  // ── Password Field ───────────────────────────────────────────────────────────
  Widget _passwordField(dynamic t, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.get('password'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: _passCtrl, obscureText: _obscurePass,
        autofillHints: const [AutofillHints.password],
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
        decoration: _dec(isDark, t.get('password_hint'), Icons.lock_outline_rounded).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), size: 19),
            onPressed: () => setState(() => _obscurePass = !_obscurePass))),
        validator: (v) {
          if (v == null || v.isEmpty) return t.get('err_password_empty');
          return null;
        }),
    ]);
  }

  // ── Remember Me + Forgot Password Row ────────────────────────────────────────
  Widget _rememberRow(dynamic t, bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      GestureDetector(
        onTap: () => setState(() => _rememberMe = !_rememberMe),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: _rememberMe ? const Color(0xFF3B82F6) : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _rememberMe ? const Color(0xFF3B82F6)
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                width: 1.5)),
            child: _rememberMe
                ? const Icon(Icons.check, color: Colors.white, size: 13)
                : null),
          const SizedBox(width: 8),
          Text(t.get('remember_me'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF374151))),
        ]),
      ),
      TextButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('Forgot password?',
          style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w600))),
    ]);
  }

  // ── Input Decoration ─────────────────────────────────────────────────────────
  InputDecoration _dec(bool isDark, String hint, IconData icon) {
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final hintC = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintC, fontSize: 14),
      prefixIcon: Icon(icon, color: hintC, size: 19),
      filled: true, fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
    );
  }
}

// ── Google "G" Logo Painter (fallback when PNG missing) ───────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final center = Offset(s / 2, s / 2);
    final radius = s / 2 - 1;

    // Blue arc (top-right)
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.6, 1.9, false, bluePaint);

    // Green arc (bottom-right)
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.3, 1.1, false, greenPaint);

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.4, 0.9, false, yellowPaint);

    // Red arc (top-left)
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5, 0.9, false, redPaint);

    // Horizontal bar
    final barPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(s * 0.48, s * 0.42, s * 0.42, s * 0.16), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}