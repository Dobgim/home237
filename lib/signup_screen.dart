import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'app_localizations.dart';
import 'auth_service.dart';
import 'signin_screen.dart';
import 'email_verification_screen.dart';
import 'home_page.dart';
import 'tenant_dashboard.dart';
import 'landlord_dashboard.dart';
import 'admin_dashboard.dart';
import 'theme_notifier.dart';
import 'widgets/language_toggle.dart';

class SignUpScreen extends StatefulWidget {
  /// Optional role chosen on the marketing site (?role=tenant|landlord),
  /// pre-selects the Tenant/Landlord card.
  final UserRole? preselectedRole;
  const SignUpScreen({super.key, this.preselectedRole});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  final bool _obscureConfirm = true;
  UserRole? _selectedRole;

  // Password strength
  double _pwStrength = 0.0;
  Color _pwColor = Colors.transparent;
  String _pwLabel = '';

  // Animations
  late AnimationController _aniCtrl;
  late Animation<double> _fadeAni;
  late Animation<Offset> _slideAni;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.preselectedRole; // primed from the marketing site, if any
    _aniCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAni = CurvedAnimation(parent: _aniCtrl, curve: Curves.easeOut);
    _slideAni = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _aniCtrl, curve: Curves.easeOut));
    _aniCtrl.forward();
  }

  @override
  void dispose() {
    _aniCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _updatePwStrength(String val) {
    double s = 0;
    if (val.length >= 6) s += 0.25;
    if (val.length >= 8) s += 0.15;
    if (val.contains(RegExp(r'[A-Z]'))) s += 0.2;
    if (val.contains(RegExp(r'[0-9]'))) s += 0.2;
    if (val.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.2;
    s = s.clamp(0.0, 1.0);
    Color c; String label;
    if (s < 0.3) { c = const Color(0xFFEF4444); label = 'Weak'; }
    else if (s < 0.55) { c = const Color(0xFFF59E0B); label = 'Fair'; }
    else if (s < 0.8) { c = const Color(0xFF10B981); label = 'Good'; }
    else { c = const Color(0xFF059669); label = 'Strong'; }
    setState(() { _pwStrength = s; _pwColor = c; _pwLabel = label; });
  }

  void _routeToDashboard() {
    Widget dest;
    if (authService.userRole == UserRole.tenant) {
      dest = TenantDashboard();
    } else if (authService.userRole == UserRole.landlord) {
      dest = LandlordDashboard();
    } else if (authService.userRole == UserRole.admin) {
      dest = AdminDashboard();
    } else {
      dest = HomePage();
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => dest), (r) => false);
  }

  void _showRoleSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Please select your role first', style: TextStyle(fontWeight: FontWeight.w500)),
      ]),
      backgroundColor: const Color(0xFF6366F1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _handleGoogleSignUp() async {
    if (_selectedRole == null) { _showRoleSnackbar(); return; }
    final success = await authService.signInWithGoogle(defaultRole: _selectedRole);
    if (mounted) {
      if (success) {
        TextInput.finishAutofillContext();
        context.read<ThemeNotifier>().updateThemeForRole();
        _routeToDashboard();
      } else if (authService.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authService.lastError!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      } else {
        // No error and not success means redirect fallback is starting, show loading spinner
        setState(() => _isLoading = true);
      }
    }
  }


  void _showHumanVerificationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2937) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  "Security Check",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please verify you are human before continuing.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setDialogState(() => isVerifying = true);
                            // Simulate professional verification delay
                            await Future.delayed(const Duration(seconds: 2));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _executeFirebaseSignUp(); // Proceed to actual sign up
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      isVerifying ? "Verifying..." : "Tap to Verify",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) { _showRoleSnackbar(); return; }
    
    // Show the professional human verification dialog first
    _showHumanVerificationDialog();
  }

  Future<void> _executeFirebaseSignUp() async {
    setState(() => _isLoading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);
      try {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'role': _selectedRole!.toString().split('.').last,
          'createdAt': DateTime.now(),
          'emailVerified': false,
          'hasSeenWelcome': false,
          'subscriptionStatus': 'free',
        });
      } catch (dbErr) { debugPrint('DB error: $dbErr'); }
      try { await cred.user?.sendEmailVerification(); } catch (_) {}
      setState(() => _isLoading = false);
      if (mounted) {
        TextInput.finishAutofillContext();
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => EmailVerificationScreen(
            email: _emailCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            selectedRole: _selectedRole!,
          )), (r) => false);
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
          margin: const EdgeInsets.all(16),
        ));
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
          margin: const EdgeInsets.all(16),
        ));
      }
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
                        blurRadius: 28, offset: const Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _googleBtn(isDark),
                            const SizedBox(height: 22),
                            _divider(isDark, 'or create account with email'),
                            const SizedBox(height: 22),
                            _roleSection(t, isDark),
                            const SizedBox(height: 22),
                            _field(label: t.get('full_name'), ctrl: _nameCtrl,
                              hint: t.get('full_name_hint'), icon: Icons.person_outline_rounded,
                              isDark: isDark, autofill: AutofillHints.name,
                              validator: (v) => v == null || v.isEmpty ? t.get('err_name_empty') : null),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleEmailSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.55),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : Text(t.get('sign_up'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('${t.get('already_have_account')} ',
                                style: TextStyle(fontSize: 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(context,
                                  MaterialPageRoute(builder: (_) => SignInScreen(preselectedRole: widget.preselectedRole))),
                                child: const Text('Sign In',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
                              ),
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
          colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
      ),
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
              const Text('Create Account',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Join Home237 and find your perfect home',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
            ])),
          ]),
        ),
      ),
    );
  }

  // ── Google Button ────────────────────────────────────────────────────────────
  Widget _googleBtn(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isLoading ? null : _handleGoogleSignUp,
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
                      errorBuilder: (_, _, _) => CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter())),
                  ),
            const SizedBox(width: 10),
            const Text('Continue with Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222), letterSpacing: -0.2)),
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

  // ── Role Selection ───────────────────────────────────────────────────────────
  Widget _roleSection(dynamic t, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('I am a…',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF374151))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _roleCard(role: UserRole.tenant, icon: Icons.home_outlined,
          title: t.get('tenant'), subtitle: 'Looking to rent', isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _roleCard(role: UserRole.landlord, icon: Icons.vpn_key_outlined,
          title: t.get('landlord'), subtitle: 'Listing properties', isDark: isDark)),
      ]),
    ]);
  }

  Widget _roleCard({required UserRole role, required IconData icon,
      required String title, required String subtitle, required bool isDark}) {
    final sel = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF3B82F6).withOpacity(isDark ? 0.18 : 0.07)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? const Color(0xFF3B82F6)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: sel ? 2 : 1.5),
        ),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF3B82F6)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: sel ? Colors.white : const Color(0xFF3B82F6), size: 20)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: sel ? const Color(0xFF3B82F6) : (isDark ? Colors.white : const Color(0xFF1E293B)))),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  // ── Generic Input Field ──────────────────────────────────────────────────────
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
        autofillHints: const [AutofillHints.newPassword],
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
        onChanged: _updatePwStrength,
        decoration: _dec(isDark, t.get('password_hint'), Icons.lock_outline_rounded).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF), size: 19),
            onPressed: () => setState(() => _obscurePass = !_obscurePass))),
        validator: (v) {
          if (v == null || v.isEmpty) return t.get('err_password_empty');
          if (v.length < 6) return t.get('password_too_short');
          return null;
        }),
      if (_pwStrength > 0) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _pwStrength, minHeight: 4,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(_pwColor)))),
          const SizedBox(width: 10),
          Text(_pwLabel, style: TextStyle(fontSize: 11, color: _pwColor, fontWeight: FontWeight.w700)),
        ]),
      ],
    ]);
  }

  // ── Password Field ───────────────────────────────────────────────────────────
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

    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.6, 1.9, false, bluePaint);

    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.3, 1.1, false, greenPaint);

    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.4, 0.9, false, yellowPaint);

    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = s * 0.18..strokeCap = StrokeCap.butt;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5, 0.9, false, redPaint);

    final barPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(s * 0.48, s * 0.42, s * 0.42, s * 0.16), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}